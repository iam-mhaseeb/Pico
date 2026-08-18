import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    let aiService: AIService
    let accessibilityManager: AccessibilityManager
    let clipboardManager: ClipboardManager
    let hotkeyManager: GlobalHotkeyManager
    let textProcessor: TextProcessor
    let conversationStore: ConversationStore
    let modelContainer: ModelContainer
    let screenAgent: ScreenAgent

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let aiService = AIService()
        let accessibilityManager = AccessibilityManager()
        let clipboardManager = ClipboardManager()
        let hotkeyManager = GlobalHotkeyManager()
        let textProcessor = TextProcessor(
            accessibility: accessibilityManager,
            clipboard: clipboardManager,
            aiService: aiService
        )
        let conversationStore = ConversationStore(modelContext: modelContainer.mainContext)
        let screenAgent = ScreenAgent()

        self.aiService = aiService
        self.accessibilityManager = accessibilityManager
        self.clipboardManager = clipboardManager
        self.hotkeyManager = hotkeyManager
        self.textProcessor = textProcessor
        self.conversationStore = conversationStore
        self.screenAgent = screenAgent
        ScreenRuntime.agent = screenAgent
    }
}
