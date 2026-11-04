import Foundation

/// Splits long text on paragraph, then sentence, then character boundaries so each piece fits
/// the on-device model. Joining the pieces always reproduces the original text exactly.
enum TextChunker {
    static func split(_ text: String, limit: Int) -> [String] {
        guard limit > 0, text.count > limit else { return [text] }

        var pieces: [String] = []
        for paragraph in units(of: text, by: .byParagraphs) {
            if paragraph.count <= limit {
                pieces.append(paragraph)
                continue
            }
            for sentence in units(of: paragraph, by: .bySentences) {
                if sentence.count <= limit {
                    pieces.append(sentence)
                } else {
                    pieces.append(contentsOf: hardSplit(sentence, limit: limit))
                }
            }
        }

        // Safety net: never lose text if enumeration ever returns gaps.
        guard pieces.joined() == text else { return hardSplit(text, limit: limit) }

        var chunks: [String] = []
        var current = ""
        for piece in pieces {
            if !current.isEmpty, current.count + piece.count > limit {
                chunks.append(current)
                current = ""
            }
            current += piece
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    static func trailingWhitespace(of text: String) -> String {
        guard let lastContent = text.lastIndex(where: { !$0.isWhitespace }) else { return text }
        return String(text[text.index(after: lastContent)...])
    }

    private static func units(of text: String, by options: String.EnumerationOptions) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: options.union(.substringNotRequired)
        ) { _, _, enclosing, _ in
            result.append(String(text[enclosing]))
        }
        return result
    }

    private static func hardSplit(_ text: String, limit: Int) -> [String] {
        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: limit, limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[start..<end]))
            start = end
        }
        return result
    }
}
