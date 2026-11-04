import Foundation

/// Detects when a user is asking Pico to look at the screen or control the UI.
enum ScreenIntent {
    static func requestsScreenHelp(_ prompt: String) -> Bool {
        let text = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return looksAtScreen(text) || actsOnScreen(text)
    }

    static func looksAtScreen(_ text: String) -> Bool {
        let patterns = [
            #"look(ing)? at (my |the )?(screen|display|window|page)"#,
            #"what('?s| is) on (my |the )?(screen|display)"#,
            #"what do you see"#,
            #"can you see (my |the )?(screen|this|that)"#,
            #"describe (my |the |this )?(screen|window|page|display)"#,
            #"screenshot"#,
            #"\b(summari[sz]e|explain|read|translate) (this|the|my) (window|page|screen)"#,
            #"on (my |the )screen"#,
            #"read (the |my )?(screen|display)"#,
            #"follow (the )?(instructions|prompt) on (the |my )?(screen|display)"#,
            #"instructions on (my |the )?(screen|display)"#
        ]
        return matches(any: patterns, in: text)
    }

    /// Action verbs only count when they open the request ("click Save", "please type …") so
    /// ordinary questions like "how do I submit a pull request?" never trigger screen capture.
    private static let lead = #"(?:^|\b(?:please|can you|could you|would you|will you|go ahead and|then)\s+)"#

    static func actsOnScreen(_ text: String) -> Bool {
        let verbs = [
            #"click(ing)?\b"#,
            #"tap(ping)?\b"#,
            #"press (the |this )?"#,
            #"type (into|in|this)"#,
            #"fill (out |in )?(this|the|my)?"#,
            #"select the "#,
            #"check( the)? box"#,
            #"uncheck\b"#,
            #"open the (menu|dropdown|popup)"#,
            #"scroll "#,
            #"hit (enter|return|tab|escape|esc)\b"#,
            #"submit (this|the|my|it)\b"#
        ]
        return matches(any: verbs.map { lead + $0 }, in: text)
    }

    private static func matches(any patterns: [String], in text: String) -> Bool {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }
        return false
    }
}
