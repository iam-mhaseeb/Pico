import Foundation
import SwiftUI

@MainActor
@Observable
final class TextActionMenuViewModel {
    enum Phase {
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

    private let processor: TextProcessor
    var onPetState: ((PetState) -> Void)?
    var onFinished: (() -> Void)?

    init(processor: TextProcessor) {
        self.processor = processor
    }

    func prepare() async {
        do {
            let capture = try await processor.captureSelection()
            originalText = capture.text
            strategy = capture.strategy
            selectionRect = capture.selectionRect
            pasteboardSnapshot = capture.pasteboardSnapshot
            phase = .chooseAction
            onPetState?(.listening)
        } catch let error as TextProcessor.CaptureError {
            switch error {
            case .accessibilityRequired:
                phase = .permissionRequired
            case .noSelection:
                phase = .emptySelection
            case .clipboardFailed:
                phase = .error(error.localizedDescription)
            }
            onPetState?(.error)
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
            onPetState?(.success)
        } catch {
            phase = .error((error as? LocalizedError)?.errorDescription ?? AIError.generationFailed.localizedDescription)
            onPetState?(.error)
        }
    }

    func insert() async {
        do {
            try await processor.insert(
                result: suggestedText,
                strategy: strategy,
                pasteboardSnapshot: pasteboardSnapshot
            )
            onPetState?(.success)
            onFinished?()
        } catch {
            phase = .error((error as? LocalizedError)?.errorDescription ?? TextReplacementError.replaceFailed.localizedDescription)
            onPetState?(.error)
        }
    }

    func cancel() {
        processor.cancelClipboardRestore(pasteboardSnapshot)
        onPetState?(.idle)
        onFinished?()
    }
}
