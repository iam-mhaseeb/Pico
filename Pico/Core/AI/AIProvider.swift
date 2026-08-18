import Foundation

enum AIUnavailableReason: Sendable, Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknown
}

enum AIError: LocalizedError, Sendable, Equatable {
    case unavailable(AIUnavailableReason)
    case generationFailed
    case cancelled
    case emptyPrompt
    case inputTooLarge

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This Mac can’t run on-device AI."
            case .appleIntelligenceNotEnabled:
                return "Turn on Apple Intelligence in System Settings."
            case .modelNotReady:
                return "Local AI isn’t ready yet. Try again in a moment."
            case .unknown:
                return "The local AI isn’t available right now."
            }
        case .generationFailed:
            return "Hmm, I couldn’t do that."
        case .cancelled:
            return "Cancelled."
        case .emptyPrompt:
            return "Type something first."
        case .inputTooLarge:
            return "That text is a bit too long for me. Try a shorter selection."
        }
    }
}

protocol AIProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func availability() async -> Result<Void, AIError>
    func stream(
        prompt: String,
        sessionID: UUID?,
        instructions: String?,
        extraContext: String?
    ) -> AsyncThrowingStream<String, Error>
    func generate(prompt: String, instructions: String?) async throws -> String
    func cancel(sessionID: UUID?)
    func seedHistory(sessionID: UUID, messages: [(role: String, content: String)])
    func dropSession(sessionID: UUID)
}
