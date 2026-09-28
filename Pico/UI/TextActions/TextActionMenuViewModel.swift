import Foundation
import SwiftUI

@MainActor
@Observable
final class TextActionMenuViewModel {
    enum Phase: Equatable {
        case permissionRequired
        case emptySelection
        case chooseAction
        case processing
        case preview
        case error(String)
    }

    var phase: Phase = .chooseAction
    var selectedAction: TextAction?
    var originalText = ""
    var suggestedText = ""
    var selectionRect: CGRect?
    private var strategy: TextReplacementStrategy = .clipboard
    private var pasteboardSnapshot: PasteboardSnapshot?
    private var sourceAppPID: pid_t?
    private var didFinish = false

    private let processor: TextProcessor
    var onPetState: ((PetState) -> Void)?
    var onFinished: (() -> Void)?

    init(processor: TextProcessor) {
        self.processor = processor
    }

    func apply(capture: TextProcessor.CaptureResult) {
        originalText = capture.text
        strategy = capture.strategy
        selectionRect = capture.selectionRect
        pasteboardSnapshot = capture.pasteboardSnapshot
        sourceAppPID = capture.sourceAppPID
        phase = .chooseAction
        onPetState?(.listening)
    }

    func apply(error: TextProcessor.CaptureError) {
        switch error {
        case .accessibilityRequired:
            phase = .permissionRequired
            onPetState?(.curious)
        case .noSelection:
            phase = .emptySelection
            onPetState?(.curious)
        case .clipboardFailed:
            phase = .error(error.localizedDescription)
            onPetState?(.error)
        }
    }

    func prepare() async {
        do {
            let capture = try await processor.captureSelection()
            apply(capture: capture)
        } catch let error as TextProcessor.CaptureError {
            apply(error: error)
        } catch {
            phase = .error(error.localizedDescription)
            onPetState?(.error)
        }
    }

    func run(_ action: TextAction) async {
        selectedAction = action
        phase = .processing
        onPetState?(.thinking)
        do {
            suggestedText = try await processor.transform(action: action, text: originalText)
            phase = .preview
            onPetState?(.curious)
        } catch let error as AIError where error == .cancelled {
            phase = .chooseAction
            onPetState?(.listening)
        } catch {
            phase = .error((error as? LocalizedError)?.errorDescription ?? AIError.generationFailed.localizedDescription)
            onPetState?(.error)
        }
    }

    @discardableResult
    func insert() async -> Bool {
        do {
            try await processor.insert(
                result: suggestedText,
                strategy: strategy,
                pasteboardSnapshot: pasteboardSnapshot,
                sourceAppPID: sourceAppPID
            )
            pasteboardSnapshot = nil
            onPetState?(.celebrating)
            finish()
            return true
        } catch {
            phase = .error((error as? LocalizedError)?.errorDescription ?? TextReplacementError.replaceFailed.localizedDescription)
            onPetState?(.error)
            return false
        }
    }

    func cancel() {
        processor.cancelTransform()
        processor.cancelClipboardRestore(pasteboardSnapshot)
        pasteboardSnapshot = nil
        onPetState?(.idle)
        finish()
    }

    /// Restore clipboard if the panel is dismissed without an explicit cancel/insert.
    func abandon() {
        processor.cancelTransform()
        processor.cancelClipboardRestore(pasteboardSnapshot)
        pasteboardSnapshot = nil
        onPetState?(.idle)
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished?()
    }
}
