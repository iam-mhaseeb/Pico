import Foundation

enum PromptTemplates {
    static let askPersonality = """
    You are Pico, a little AI buddy for the Mac.
    Tone: cute, friendly, smart, calm, and concise. Not sycophantic or corporate.
    Prefer helpful short answers. Use markdown for structure and code when useful.
    You run on-device. Do not claim to browse the web or access remote services.

    Screen help (only when the user asks to look at the screen or control the UI):
    - You may receive a screen context block and you have tools: lookAtScreen, clickElement, typeText, pressKey, clickAt.
    - Use those tools only for screen questions or UI actions. Never capture or click during ordinary chat.
    - Prefer clickElement with a name or #id from accessibility. Use clickAt with OCR boxes only as a fallback.
    - Never type passwords or interact with secure text fields.
    - After acting, say briefly what you did. If a permission is missing, tell the user how to turn it on in Settings.
    """

    private static let sharedTextConstraints = """
    Preserve the original meaning. Do not invent facts or add information.
    Return only the result text — no quotes, no preamble, no explanation.
    Preserve the original language.
    """

    static func rewrite(text: String) -> (instructions: String, prompt: String) {
        let instructions = """
        Rewrite the supplied text to improve clarity and naturalness.
        \(sharedTextConstraints)
        """
        return (instructions, text)
    }

    static func fixGrammar(text: String) -> (instructions: String, prompt: String) {
        let instructions = """
        Correct grammar, spelling, and punctuation.
        Fix obvious typing errors only. Avoid unnecessary rewriting. Preserve tone.
        \(sharedTextConstraints)
        """
        return (instructions, text)
    }

    static func makeProfessional(text: String) -> (instructions: String, prompt: String) {
        let instructions = """
        Transform the supplied text into polished, professional communication.
        \(sharedTextConstraints)
        """
        return (instructions, text)
    }

    static func makeCasual(text: String) -> (instructions: String, prompt: String) {
        let instructions = """
        Make the supplied text natural, friendly, and conversational.
        \(sharedTextConstraints)
        """
        return (instructions, text)
    }

    static func shorten(text: String) -> (instructions: String, prompt: String) {
        let instructions = """
        Reduce unnecessary words while preserving the original meaning.
        \(sharedTextConstraints)
        """
        return (instructions, text)
    }

    static func improve(text: String) -> (instructions: String, prompt: String) {
        let instructions = """
        Improve clarity, grammar, flow, and readability while preserving intent.
        \(sharedTextConstraints)
        """
        return (instructions, text)
    }

    static func composeAskPrompt(
        user: String,
        history: [(role: String, content: String)]?,
        screen: String?,
        toneHint: String? = nil
    ) -> String {
        var parts: [String] = []
        if let toneHint, !toneHint.isEmpty {
            parts.append("Dialogue vibe: \(toneHint)")
        }
        if let history, !history.isEmpty {
            let historyBlock = history.map { "\($0.role): \($0.content)" }.joined(separator: "\n")
            parts.append("Previous conversation:\n\(historyBlock)")
        }
        if let screen, !screen.isEmpty {
            parts.append(
                "Screen context for this turn only (not written by the user):\n\(screen)"
            )
        }
        if parts.isEmpty {
            return user
        }
        parts.append("User:\n\(user)")
        return parts.joined(separator: "\n\n")
    }
}
