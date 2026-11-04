import Foundation

enum PromptValidation {
    static let maxPromptCharacters = 12_000

    static func validatedPrompt(_ prompt: String) throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.emptyPrompt }
        guard trimmed.count <= maxPromptCharacters else { throw AIError.inputTooLarge }
        return trimmed
    }
}
