import Foundation

enum TextReplacementStrategy: Sendable {
    case accessibility
    case clipboard
}

enum TextReplacementError: LocalizedError, Sendable {
    case replaceFailed
    case noSelection

    var errorDescription: String? {
        switch self {
        case .replaceFailed:
            return "I couldn’t insert the text into that app."
        case .noSelection:
            return "Select some text first and I’ll help you improve it."
        }
    }
}

struct TextReplacement: Sendable {
    let originalText: String
    let strategy: TextReplacementStrategy
}
