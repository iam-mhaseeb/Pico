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
    }
}
