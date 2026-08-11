import Foundation

@MainActor
final class AIService {
    private let provider: any AIProvider

    init(provider: any AIProvider = MacAIProvider()) {
        self.provider = provider
    }

    var providerID: String { provider.id }
    var providerDisplayName: String { provider.displayName }

    func availability() async -> Result<Void, AIError> {
        await provider.availability()
    }

    func ask(prompt: String, conversationID: UUID?) -> AsyncThrowingStream<String, Error> {
        provider.stream(
            prompt: prompt,
            sessionID: conversationID,
            instructions: PromptTemplates.askPersonality
        )
    }

    func seedHistory(conversationID: UUID, messages: [(role: String, content: String)]) {
        provider.seedHistory(sessionID: conversationID, messages: messages)
    }

    func dropSession(conversationID: UUID) {
        provider.dropSession(sessionID: conversationID)
    }

    func cancelAsk(conversationID: UUID?) {
        provider.cancel(sessionID: conversationID)
    }

    func rewrite(_ text: String) async throws -> String {
        let pair = PromptTemplates.rewrite(text: text)
        return try await provider.generate(prompt: pair.prompt, instructions: pair.instructions)
    }

    func fixGrammar(_ text: String) async throws -> String {
        let pair = PromptTemplates.fixGrammar(text: text)
        return try await provider.generate(prompt: pair.prompt, instructions: pair.instructions)
    }

    func makeProfessional(_ text: String) async throws -> String {
        let pair = PromptTemplates.makeProfessional(text: text)
        return try await provider.generate(prompt: pair.prompt, instructions: pair.instructions)
    }

    func makeCasual(_ text: String) async throws -> String {
        let pair = PromptTemplates.makeCasual(text: text)
        return try await provider.generate(prompt: pair.prompt, instructions: pair.instructions)
    }

    func shorten(_ text: String) async throws -> String {
        let pair = PromptTemplates.shorten(text: text)
        return try await provider.generate(prompt: pair.prompt, instructions: pair.instructions)
    }

    func improve(_ text: String) async throws -> String {
        let pair = PromptTemplates.improve(text: text)
        return try await provider.generate(prompt: pair.prompt, instructions: pair.instructions)
    }

    func perform(action: TextAction, on text: String) async throws -> String {
        switch action {
        case .rewrite:
            return try await rewrite(text)
        case .fixGrammar:
            return try await fixGrammar(text)
        case .makeProfessional:
            return try await makeProfessional(text)
        case .makeCasual:
            return try await makeCasual(text)
        case .makeShorter:
            return try await shorten(text)
        case .improve:
            return try await improve(text)
        }
    }
}
