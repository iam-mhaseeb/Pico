import Foundation

/// Word-level comparison used to highlight what Pico changed in a suggestion.
enum TextDiff {
    /// Splits text into alternating runs of words and whitespace.
    static func tokens(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var currentIsSpace: Bool?
        for character in text {
            let isSpace = character.isWhitespace
            if let currentIsSpace, currentIsSpace != isSpace {
                result.append(current)
                current = ""
            }
            currentIsSpace = isSpace
            current.append(character)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Tokens of `suggested` plus the indices that are new compared with `original`.
    static func compare(original: String, suggested: String) -> (tokens: [String], inserted: Set<Int>) {
        let old = tokens(original)
        let new = tokens(suggested)
        var inserted = Set<Int>()
        for change in new.difference(from: old) {
            if case .insert(let offset, _, _) = change {
                inserted.insert(offset)
            }
        }
        // Whitespace on its own is never worth highlighting.
        let words = inserted.filter { !new[$0].allSatisfy(\.isWhitespace) }
        return (new, Set(words))
    }
}
