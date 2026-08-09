import Foundation

enum PromptTemplates {
    static let askPersonality = """
    You are Pico, a little AI buddy for the Mac.
    Tone: cute, friendly, smart, calm, and concise. Not sycophantic or corporate.
    Prefer helpful short answers. Use markdown for structure and code when useful.
    You run on-device. Do not claim to browse the web or access remote services.
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
}
