import Foundation

@MainActor
final class AppEnvironment {
    let aiService: AIService
    let accessibilityManager: AccessibilityManager
    let clipboardManager: ClipboardManager
    let hotkeyManager: GlobalHotkeyManager
    let textProcessor: TextProcessor

    init() {
        let aiService = AIService()
        let accessibilityManager = AccessibilityManager()
        let clipboardManager = ClipboardManager()
        let textProcessor = TextProcessor(
            accessibility: accessibilityManager,
            clipboard: clipboardManager,
            aiService: aiService
        )

        self.aiService = aiService
        self.accessibilityManager = accessibilityManager
        self.clipboardManager = clipboardManager
        self.hotkeyManager = GlobalHotkeyManager()
        self.textProcessor = textProcessor
    }
}
