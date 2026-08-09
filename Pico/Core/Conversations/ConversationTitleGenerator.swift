import Foundation

enum ConversationTitleGenerator {
    private static let maxLength = 42

    static func title(from firstUserMessage: String) -> String {
        let trimmed = firstUserMessage
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return "New conversation"
        }

        if trimmed.count <= maxLength {
            return trimmed
        }

        let truncated = String(trimmed.prefix(maxLength))
        if let lastSpace = truncated.lastIndex(of: " "), lastSpace > truncated.startIndex {
            return String(truncated[..<lastSpace]).trimmingCharacters(in: .whitespaces)
        }
        return truncated
    }
}
