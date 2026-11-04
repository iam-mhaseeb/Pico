import AppKit
import Foundation

@MainActor
final class TextProcessor {
    private let accessibility: any AccessibilityProviding
    private let clipboard: ClipboardManager
    private let aiService: AIService
    private let keyEvents: any KeyEventSynthesizing
    private var transformTask: Task<String, Error>?

    init(
        accessibility: any AccessibilityProviding,
        clipboard: ClipboardManager,
        aiService: AIService,
        keyEvents: any KeyEventSynthesizing = SystemKeyEventSynthesizer()
    ) {
        self.accessibility = accessibility
        self.clipboard = clipboard
        self.aiService = aiService
        self.keyEvents = keyEvents
    }

    struct CaptureResult {
        let text: String
        let strategy: TextReplacementStrategy
        let selectionRect: CGRect?
        let pasteboardSnapshot: PasteboardSnapshot?
        let sourceAppPID: pid_t?
    }

    enum CaptureError: LocalizedError {
        case accessibilityRequired
        case noSelection
        case clipboardFailed

        var errorDescription: String? {
            switch self {
            case .accessibilityRequired:
                return "Pico needs Accessibility access to help with selected text."
            case .noSelection:
                return "Select some text first and I’ll help you improve it."
            case .clipboardFailed:
                return "I couldn’t read the selected text from that app."
            }
        }
    }

    func captureSelection() async throws -> CaptureResult {
        let sourcePID = FrontmostAppHelper.currentPID()

        if let axText = accessibility.selectedText(), !axText.isEmpty {
            return CaptureResult(
                text: axText,
                strategy: .accessibility,
                selectionRect: accessibility.selectedTextRect(),
                pasteboardSnapshot: nil,
                sourceAppPID: sourcePID
            )
        }

        guard accessibility.isTrusted else {
            throw CaptureError.accessibilityRequired
        }

        let snapshot = clipboard.snapshot()
        let changeBefore = clipboard.changeCount
        keyEvents.copy()

        do {
            var changed = false
            for _ in 0..<25 {
                try await Task.sleep(nanoseconds: 40_000_000)
                if clipboard.changeCount != changeBefore {
                    changed = true
                    break
                }
            }

            guard changed else {
                clipboard.restore(snapshot)
                throw CaptureError.noSelection
            }

            guard let copied = clipboard.readString(), !copied.isEmpty else {
                clipboard.restore(snapshot)
                throw CaptureError.noSelection
            }

            // Keep exact selection; only reject whitespace-only captures.
            if copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clipboard.restore(snapshot)
                throw CaptureError.noSelection
            }

            return CaptureResult(
                text: copied,
                strategy: .clipboard,
                selectionRect: accessibility.selectedTextRect(),
                pasteboardSnapshot: snapshot,
                sourceAppPID: sourcePID
            )
        } catch is CancellationError {
            clipboard.restore(snapshot)
            throw CancellationError()
        } catch {
            // CaptureError paths already restore; other unexpected failures restore too.
            if !(error is CaptureError) {
                clipboard.restore(snapshot)
            }
            throw error
        }
    }

    func transform(action: TextAction, text: String) async throws -> String {
        transformTask?.cancel()
        let service = aiService
        let task = Task {
            try await service.perform(action: action, on: text)
        }
        transformTask = task
        // Only clear our own task; a newer transform may have replaced it while we awaited.
        defer { if transformTask == task { transformTask = nil } }
        do {
            return try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch is CancellationError {
            throw AIError.cancelled
        }
    }

    func cancelTransform() {
        // Cancelling the task reaches the provider's generate() via its cancellation handler,
        // so in-flight Ask streams are left alone.
        transformTask?.cancel()
        transformTask = nil
    }

    func insert(
        result: String,
        strategy: TextReplacementStrategy,
        pasteboardSnapshot: PasteboardSnapshot?,
        sourceAppPID: pid_t?
    ) async throws {
        await FrontmostAppHelper.activate(pid: sourceAppPID)

        switch strategy {
        case .accessibility:
            if accessibility.setSelectedText(result) {
                return
            }
            try await pasteViaClipboard(result, restoring: pasteboardSnapshot)
        case .clipboard:
            try await pasteViaClipboard(result, restoring: pasteboardSnapshot)
        }
    }

    func cancelClipboardRestore(_ snapshot: PasteboardSnapshot?) {
        if let snapshot {
            clipboard.restore(snapshot)
        }
    }

    private func pasteViaClipboard(_ result: String, restoring snapshot: PasteboardSnapshot?) async throws {
        let localSnapshot = snapshot ?? clipboard.snapshot()
        // Restore even if the wait below is cancelled.
        defer { clipboard.restore(localSnapshot) }
        clipboard.writeString(result)
        let changeBeforePaste = clipboard.changeCount
        keyEvents.paste()

        // Give the target app time to read the pasteboard before restore.
        // changeCount may not move on paste, so always wait a minimum before restoring.
        for step in 0..<15 {
            try await Task.sleep(nanoseconds: 40_000_000)
            if step >= 3, clipboard.changeCount != changeBeforePaste {
                break
            }
        }
    }
}
