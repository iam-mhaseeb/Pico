import Foundation

@MainActor
final class AIService {
    /// The on-device model has a small context window, so long selections are processed in pieces.
    static let maxChunkCharacters = 3_000

    private let provider: any AIProvider

    init(provider: any AIProvider = MacAIProvider()) {
        self.provider = provider
    }

    var providerID: String { provider.id }
    var providerDisplayName: String { provider.displayName }

    func availability() async -> Result<Void, AIError> {
        await provider.availability()
    }

    func perform(action: TextAction, on text: String) async throws -> String {
        guard text.count <= PromptValidation.maxPromptCharacters else {
            throw AIError.inputTooLarge
        }

        var output = ""
        for chunk in TextChunker.split(text, limit: Self.maxChunkCharacters) {
            try Task.checkCancellation()
            let core = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !core.isEmpty else {
                output += chunk
                continue
            }
            // Keep the original spacing around each piece so paragraphs stay where they were.
            let leading = String(chunk.prefix(while: \.isWhitespace))
            let trailing = TextChunker.trailingWhitespace(of: chunk)
            let pair = PromptTemplates.pair(for: action, text: core)
            let result = try await provider.generate(prompt: pair.prompt, instructions: pair.instructions)
            output += leading + result.trimmingCharacters(in: .whitespacesAndNewlines) + trailing
        }
        return output
    }
}
