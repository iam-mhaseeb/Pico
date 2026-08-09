import Foundation

@MainActor
final class TextProcessor {
    private let accessibility: AccessibilityManager
    private let clipboard: ClipboardManager
    private let aiService: AIService

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
        if let axText = accessibility.selectedText(), !axText.isEmpty {
            return CaptureResult(
                text: axText,
                strategy: .accessibility,
                selectionRect: accessibility.selectedTextRect(),
                pasteboardSnapshot: nil
            )
        }

        guard accessibility.isTrusted else {
            throw CaptureError.accessibilityRequired
        }

        let snapshot = clipboard.snapshot()
        KeyEventSynthesizer.copy()
        try await Task.sleep(nanoseconds: 120_000_000)
        guard let copied = clipboard.readString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !copied.isEmpty
        else {
            clipboard.restore(snapshot)
            throw CaptureError.noSelection
        }

        return CaptureResult(
            text: copied,
            strategy: .clipboard,
            selectionRect: accessibility.selectedTextRect(),
            pasteboardSnapshot: snapshot
        )
    }

    func transform(action: TextAction, text: String) async throws -> String {
        try await aiService.perform(action: action, on: text)
    }

    func insert(
        result: String,
        strategy: TextReplacementStrategy,
        pasteboardSnapshot: PasteboardSnapshot?
    ) async throws {
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
        defer { clipboard.restore(localSnapshot) }
        clipboard.writeString(result)
        KeyEventSynthesizer.paste()
        try await Task.sleep(nanoseconds: 120_000_000)
    }
}
