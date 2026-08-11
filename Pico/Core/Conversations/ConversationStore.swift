import Foundation
import SwiftData

@MainActor
final class ConversationStore {
    private let modelContext: ModelContext
    /// Conversations created while Keep History was off — never saved to disk.
    private var ephemeralIDs: Set<UUID> = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Manual saves only — prevents ephemeral chats from being autosaved to disk.
        modelContext.autosaveEnabled = false
    }

    private var keepHistory: Bool {
        if UserDefaults.standard.object(forKey: PreferenceKey.keepHistory) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: PreferenceKey.keepHistory)
    }

    private func shouldPersist(_ conversation: Conversation) -> Bool {
        keepHistory && !ephemeralIDs.contains(conversation.id)
    }

    func createConversation(
        firstUserMessage: String,
        providerID: String
    ) throws -> Conversation {
        let conversation = Conversation(
            title: ConversationTitleGenerator.title(from: firstUserMessage),
            providerID: providerID
        )
        modelContext.insert(conversation)
        if keepHistory {
            try modelContext.save()
        } else {
            ephemeralIDs.insert(conversation.id)
        }
        return conversation
    }

    func appendMessage(
        role: String,
        content: String,
        to conversation: Conversation
    ) throws -> Message {
        let message = Message(role: role, content: content)
        message.conversation = conversation
        conversation.updatedAt = .now
        if shouldPersist(conversation) {
            try modelContext.save()
        }
        return message
    }

    func updateMessageContent(_ message: Message, content: String) throws {
        message.content = content
        message.conversation?.updatedAt = .now
        if let conversation = message.conversation, shouldPersist(conversation) {
            try modelContext.save()
        }
    }

    /// Persist streaming assistant content without saving every token.
    func setStreamingContent(_ message: Message, content: String) {
        message.content = content
        message.conversation?.updatedAt = .now
    }

    func finalizeStreaming(_ message: Message) throws {
        message.conversation?.updatedAt = .now
        if let conversation = message.conversation, shouldPersist(conversation) {
            try modelContext.save()
        }
    }

    func deleteMessage(_ message: Message) throws {
        let conversation = message.conversation
        modelContext.delete(message)
        conversation?.updatedAt = .now
        if let conversation, shouldPersist(conversation) {
            try modelContext.save()
        }
    }

    func listConversations() throws -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)
        return all.filter { !ephemeralIDs.contains($0.id) }
    }

    func delete(_ conversation: Conversation) throws {
        let wasEphemeral = ephemeralIDs.remove(conversation.id) != nil
        modelContext.delete(conversation)
        if !wasEphemeral {
            try modelContext.save()
        }
    }

    func clearAll() throws {
        let descriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(descriptor)
        for conversation in conversations {
            modelContext.delete(conversation)
        }
        ephemeralIDs.removeAll()
        try modelContext.save()
    }

    func setTitle(_ title: String, for conversation: Conversation) throws {
        conversation.title = title
        conversation.updatedAt = .now
        if shouldPersist(conversation) {
            try modelContext.save()
        }
    }
}
