import XCTest
@testable import Pico

final class PromptTemplatesTests: XCTestCase {
    func testTextActionsReturnOnlyResultInstruction() {
        let actions: [(String, String)] = [
            PromptTemplates.rewrite(text: "hello"),
            PromptTemplates.fixGrammar(text: "hello"),
            PromptTemplates.makeProfessional(text: "hello"),
            PromptTemplates.makeCasual(text: "hello"),
            PromptTemplates.shorten(text: "hello"),
            PromptTemplates.improve(text: "hello")
        ].map { ($0.instructions, $0.prompt) }

        for (instructions, prompt) in actions {
            XCTAssertTrue(instructions.contains("Return only the result text"))
            XCTAssertEqual(prompt, "hello")
        }
    }

    func testAskPersonalityMentionsOnDevice() {
        XCTAssertTrue(PromptTemplates.askPersonality.lowercased().contains("on-device"))
        XCTAssertTrue(PromptTemplates.askPersonality.contains("Pico"))
        XCTAssertTrue(PromptTemplates.askPersonality.contains("lookAtScreen"))
    }

    func testComposeAskPromptIncludesScreenAndHistory() {
        let composed = PromptTemplates.composeAskPrompt(
            user: "Click submit",
            history: [("user", "Hi"), ("assistant", "Hello")],
            screen: "APP: Safari"
        )
        XCTAssertTrue(composed.contains("Previous conversation:"))
        XCTAssertTrue(composed.contains("APP: Safari"))
        XCTAssertTrue(composed.contains("User:\nClick submit"))
        XCTAssertEqual(
            PromptTemplates.composeAskPrompt(user: "Hi", history: nil, screen: nil),
            "Hi"
        )
    }

    func testComposeAskPromptIncludesPersonaFlavor() {
        let composed = PromptTemplates.composeAskPrompt(
            user: "Hello",
            history: nil,
            screen: nil,
            toneHint: "Playfully snarky, never mean."
        )
        XCTAssertTrue(composed.contains("Dialogue vibe:"))
        XCTAssertTrue(composed.contains("snarky"))
        XCTAssertTrue(composed.contains("Hello"))
    }
}
