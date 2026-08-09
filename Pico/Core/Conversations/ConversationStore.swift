import Foundation
import SwiftData

@MainActor
final class ConversationStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private var keepHistory: Bool {
        if UserDefaults.standard.object(forKey: PreferenceKey.keepHistory) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: PreferenceKey.keepHistory)
    }

    func createConversation(
        firstUserMessage: String,
        providerID: String
    ) throws -> Conversation {
        let conversation = Conversation(
            title: ConversationTitleGenerator.title(from: firstUserMessage),
            providerID: providerID
        )
        if keepHistory {
            modelContext.insert(conversation)
            try modelContext.save()
        }
        return conversation
    }

    func appendMessage(
        role: String,
        content: String,
        to conversation: Conversation
    ) throws -> Message {
        let message = Message(role: role, content: content, conversation: conversation)
        conversation.messages.append(message)
        conversation.updatedAt = .now
        if keepHistory {
            modelContext.insert(message)
            try modelContext.save()
        }
        return message
    }

    func updateMessageContent(_ message: Message, content: String) throws {
        message.content = content
        message.conversation?.updatedAt = .now
        if keepHistory {
            try modelContext.save()
        }
    }

    func listConversations() throws -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func delete(_ conversation: Conversation) throws {
        modelContext.delete(conversation)
        try modelContext.save()
    }

    func clearAll() throws {
        let conversations = try listConversations()
        for conversation in conversations {
            modelContext.delete(conversation)
        }
        try modelContext.save()
    }

    func setTitle(_ title: String, for conversation: Conversation) throws {
        conversation.title = title
        conversation.updatedAt = .now
        if keepHistory {
            try modelContext.save()
        }
    }
}
