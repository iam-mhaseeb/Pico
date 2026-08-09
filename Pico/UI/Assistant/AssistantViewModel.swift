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

    var onPetState: ((PetState) -> Void)?

    init(aiService: AIService, store: ConversationStore?) {
        self.aiService = aiService
        self.store = store
    }

    func newConversation() {
        cancel()
        messages = []
        conversationID = nil
        activeConversation = nil
        conversationTitle = "New conversation"
        errorMessage = nil
        input = ""
    }

    func load(conversation: Conversation) {
        cancel()
        activeConversation = conversation
        conversationID = conversation.id
        conversationTitle = conversation.title
        messages = conversation.messages
            .sorted { $0.timestamp < $1.timestamp }
            .filter { $0.role == "user" || $0.role == "assistant" }
            .map { ChatMessage(id: $0.id, role: $0.role, content: $0.content) }
        aiService.seedHistory(
            conversationID: conversation.id,
            messages: messages.map { ($0.role, $0.content) }
        )
    }

    func send() {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isSending else { return }
        lastUserPrompt = prompt
        input = ""
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

                let userMessage = ChatMessage(role: "user", content: prompt)
                messages.append(userMessage)
                if let activeConversation {
                    _ = try store?.appendMessage(role: "user", content: prompt, to: activeConversation)
                }

                let assistantID = UUID()
                streamingMessageID = assistantID
                messages.append(ChatMessage(id: assistantID, role: "assistant", content: "", isStreaming: true))

                var persistedAssistant: Message?
                if let activeConversation {
                    persistedAssistant = try store?.appendMessage(
                        role: "assistant",
                        content: "",
                        to: activeConversation
                    )
                }

                let stream = aiService.ask(prompt: prompt, conversationID: conversationID)
                for try await partial in stream {
                    guard !Task.isCancelled else { break }
                    if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                        messages[index].content = partial
                    }
                    if let persistedAssistant {
                        try store?.updateMessageContent(persistedAssistant, content: partial)
                    }
                }

                if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[index].isStreaming = false
                }
                isSending = false
                streamingMessageID = nil
                onPetState?(.success)
            } catch let error as AIError where error == .cancelled {
                isSending = false
                streamingMessageID = nil
                onPetState?(.idle)
            } catch {
                isSending = false
                streamingMessageID = nil
                errorMessage = (error as? LocalizedError)?.errorDescription ?? AIError.generationFailed.localizedDescription
                onPetState?(.error)
            }
        }
    }

    func retry(_ message: ChatMessage) {
        guard let lastUserPrompt else { return }
        input = lastUserPrompt
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages.remove(at: index)
        }
        send()
    }

    func copy(_ message: ChatMessage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }

    func cancel() {
        sendTask?.cancel()
        aiService.cancelAsk(conversationID: conversationID)
        isSending = false
        streamingMessageID = nil
    }
}
