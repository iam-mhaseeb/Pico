import Foundation

/// Detects when a user is asking Pico to look at the screen or control the UI.
enum ScreenIntent {
    static func requestsScreenHelp(_ prompt: String) -> Bool {
        let text = prompt.lowercased()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return looksAtScreen(text) || actsOnScreen(text)
    }

    static func looksAtScreen(_ text: String) -> Bool {
        let patterns = [
            #"look(ing)? at (my |the )?(screen|display|window|page)"#,
            #"what('?s| is) on (my |the )?(screen|display)"#,
            #"what do you see"#,
            #"can you see (my |the )?(screen|this|that)"#,
            #"describe (my |the )?(screen|window|page|display)"#,
            #"screenshot"#,
            #"this (window|page|screen)"#,
            #"on (my |the )screen"#,
            #"read (the |my )?(screen|display)"#,
            #"follow (the )?(instructions|prompt) on (the |my )?(screen|display)"#,
            #"instructions on (my |the )?(screen|display)"#
        ]
        return matches(any: patterns, in: text)
    }

    static func actsOnScreen(_ text: String) -> Bool {
        let patterns = [
            #"\bclick(ing)?\b"#,
            #"\btap(ping)?\b"#,
            #"\bpress (the |this )?"#,
            #"\btype (into|in|this)"#,
            #"\bfill (out |in )?(this|the|my)?"#,
            #"\bselect the "#,
            #"\bcheck( the)? box"#,
            #"\buncheck\b"#,
            #"\bopen the (menu|dropdown|popup)"#,
            #"\bscroll "#,
            #"\bhit (enter|return|tab|escape|esc)\b"#,
            #"\bsubmit\b"#
        ]
        return matches(any: patterns, in: text)
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
