import AppKit
import Foundation
import SwiftUI

@MainActor
@Observable
final class AssistantViewModel {
    var messages: [ChatMessage] = []
    var input = ""
    var isSending = false
    var errorMessage: String?
    var conversationID: UUID?
    var conversationTitle = "New conversation"

    private let aiService: AIService
    private let store: ConversationStore?
    private var activeConversation: Conversation?
    private var streamingMessageID: UUID?
    private var sendTask: Task<Void, Never>?
    private var lastUserPrompt: String?
    private var streamSaveCounter = 0

    var onPetState: ((PetState) -> Void)?

    init(aiService: AIService, store: ConversationStore?) {
        self.aiService = aiService
        self.store = store
    }

    func newConversation() {
        cancelStreamingIfNeeded()
        if let conversationID {
            aiService.dropSession(conversationID: conversationID)
        }
        messages = []
        conversationID = nil
        activeConversation = nil
        conversationTitle = "New conversation"
        errorMessage = nil
        input = ""
        lastUserPrompt = nil
        sendTask = nil
    }

    func load(conversation: Conversation) {
        cancelStreamingIfNeeded()
        if let previousID = conversationID, previousID != conversation.id {
            aiService.dropSession(conversationID: previousID)
        }
        activeConversation = conversation
        conversationID = conversation.id
        conversationTitle = conversation.title
        messages = conversation.messages
            .sorted { $0.timestamp < $1.timestamp }
            .filter { $0.role == "user" || $0.role == "assistant" }
            .map { ChatMessage(id: $0.id, role: $0.role, content: $0.content) }
        sendTask = nil
        aiService.seedHistory(
            conversationID: conversation.id,
            messages: messages.map { ($0.role, $0.content) }
        )
    }

    func send() {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isSending else { return }
        input = ""
        beginGeneration(prompt: prompt, appendUserMessage: true)
    }

    /// Retry the last failed assistant turn without duplicating the user message.
    func retry(_ message: ChatMessage) {
        guard let lastUserPrompt, !isSending else { return }
        removeAssistantMessage(message)
        errorMessage = nil
        beginGeneration(prompt: lastUserPrompt, appendUserMessage: false)
    }

    /// Banner retry: remove failed assistant reply (if any) and resend last user prompt.
    func retryLastFailure() {
        guard let lastUserPrompt, !isSending else { return }
        if let lastAssistant = messages.last(where: { $0.role == "assistant" }) {
            removeAssistantMessage(lastAssistant)
        }
        errorMessage = nil
        beginGeneration(prompt: lastUserPrompt, appendUserMessage: false)
    }

    func copy(_ message: ChatMessage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }

    /// Cancel an in-flight generation only. Closing the panel should not call this unless streaming.
    func cancel() {
        cancelStreamingIfNeeded()
    }

    private func cancelStreamingIfNeeded() {
        guard isSending else { return }
        sendTask?.cancel()
        sendTask = nil
        aiService.cancelAsk(conversationID: conversationID)
        Task { await cleanupCancelledStream() }
    }

    private func beginGeneration(prompt: String, appendUserMessage: Bool) {
        lastUserPrompt = prompt
        errorMessage = nil
        isSending = true
        onPetState?(.thinking)

        sendTask = Task {
            do {
                if conversationID == nil {
                    let conversation = try store?.createConversation(
                        firstUserMessage: prompt,
                        providerID: aiService.providerID
                    )
                    activeConversation = conversation
                    conversationID = conversation?.id ?? UUID()
                    conversationTitle = conversation?.title ?? ConversationTitleGenerator.title(from: prompt)
                }

                if appendUserMessage {
                    var userID = UUID()
                    if let activeConversation,
                       let persisted = try store?.appendMessage(
                        role: "user",
                        content: prompt,
                        to: activeConversation
                       ) {
                        userID = persisted.id
                    }
                    messages.append(ChatMessage(id: userID, role: "user", content: prompt))
                }

                var assistantID = UUID()
                var persistedAssistant: Message?
                if let activeConversation {
                    persistedAssistant = try store?.appendMessage(
                        role: "assistant",
                        content: "",
                        to: activeConversation
                    )
                    if let persistedAssistant {
                        assistantID = persistedAssistant.id
                    }
                }
                streamingMessageID = assistantID
                messages.append(ChatMessage(id: assistantID, role: "assistant", content: "", isStreaming: true))

                streamSaveCounter = 0
                let stream = aiService.ask(prompt: prompt, conversationID: conversationID)
                for try await partial in stream {
                    guard !Task.isCancelled else { break }
                    if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                        messages[index].content = partial
                    }
                    if let persistedAssistant {
                        store?.setStreamingContent(persistedAssistant, content: partial)
                        streamSaveCounter += 1
                        if streamSaveCounter % 8 == 0 {
                            try store?.finalizeStreaming(persistedAssistant)
                        }
                    }
                }

                if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[index].isStreaming = false
                }
                if let persistedAssistant {
                    try store?.finalizeStreaming(persistedAssistant)
                }
                isSending = false
                streamingMessageID = nil
                sendTask = nil
                onPetState?(.success)
            } catch let error as AIError where error == .cancelled {
                await cleanupCancelledStream()
                sendTask = nil
                onPetState?(.idle)
            } catch {
                if let streamingMessageID,
                   let index = messages.firstIndex(where: { $0.id == streamingMessageID }) {
                    messages[index].isStreaming = false
                }
                isSending = false
                streamingMessageID = nil
                sendTask = nil
                errorMessage = (error as? LocalizedError)?.errorDescription ?? AIError.generationFailed.localizedDescription
                // Provider resets the session on failure — re-seed remaining turns.
                if let conversationID {
                    let history = messages.filter { !$0.isStreaming && !$0.content.isEmpty }
                    aiService.seedHistory(
                        conversationID: conversationID,
                        messages: history.map { ($0.role, $0.content) }
                    )
                }
                onPetState?(.error)
            }
        }
    }

    private func removeAssistantMessage(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            let removed = messages.remove(at: index)
            if let store,
               let activeConversation,
               let model = activeConversation.messages.first(where: { $0.id == removed.id }) {
                try? store.deleteMessage(model)
            }
        }
    }

    private func cleanupCancelledStream() async {
        if let streamingMessageID,
           let index = messages.firstIndex(where: { $0.id == streamingMessageID }) {
            let removed = messages.remove(at: index)
            if let store,
               let activeConversation,
               let model = activeConversation.messages.first(where: { $0.id == removed.id }) {
                try? store.deleteMessage(model)
            }
        }
        isSending = false
        streamingMessageID = nil
        // Mid-stream cancel resets the on-device session — re-seed from UI history.
        if let conversationID, !messages.isEmpty {
            aiService.seedHistory(
                conversationID: conversationID,
                messages: messages.map { ($0.role, $0.content) }
            )
        }
    }
}
