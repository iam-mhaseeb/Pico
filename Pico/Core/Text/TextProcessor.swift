import AppKit
import Foundation

@MainActor
final class TextProcessor {
    private let accessibility: AccessibilityManager
    private let clipboard: ClipboardManager
    private let aiService: AIService
    private var transformTask: Task<String, Error>?

    init(
        accessibility: AccessibilityManager,
        clipboard: ClipboardManager,
        aiService: AIService
    ) {
        self.accessibility = accessibility
        self.clipboard = clipboard
        self.aiService = aiService
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
        KeyEventSynthesizer.copy()

        do {
            var changed = false
            for _ in 0..<12 {
                try await Task.sleep(nanoseconds: 40_000_000)
                if clipboard.changeCount != changeBefore {
                    changed = true
                    break
                }
            }

            guard changed else {
                clipboard.restore(snapshot)
                throw CaptureError.clipboardFailed
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
        let task = Task {
            try await aiService.perform(action: action, on: text)
        }
        transformTask = task
        do {
            let result = try await task.value
            transformTask = nil
            return result
        } catch is CancellationError {
            transformTask = nil
            throw AIError.cancelled
        } catch {
            transformTask = nil
            throw error
        }
    }

    func cancelTransform() {
        transformTask?.cancel()
        transformTask = nil
        aiService.cancelAsk(conversationID: nil)
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
        clipboard.writeString(result)
        let changeBeforePaste = clipboard.changeCount
        KeyEventSynthesizer.paste()

        // Give the target app time to read the pasteboard before restore.
        var settled = false
        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 40_000_000)
            // Prefer waiting a bit after paste event; changeCount may not move on paste.
            settled = true
            if clipboard.changeCount != changeBeforePaste {
                break
            }
        }
        _ = settled
        clipboard.restore(localSnapshot)
    }
}
