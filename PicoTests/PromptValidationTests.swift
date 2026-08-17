import XCTest
@testable import Pico

final class PromptValidationTests: XCTestCase {
    func testEmptyPromptFails() {
        XCTAssertThrowsError(try PromptValidation.validatedPrompt("   ")) { error in
            XCTAssertEqual(error as? AIError, .emptyPrompt)
        }
    }

    func testTrimsPrompt() throws {
        XCTAssertEqual(try PromptValidation.validatedPrompt("  hello  "), "hello")
    }

    func testTooLargePromptFails() {
        let huge = String(repeating: "a", count: PromptValidation.maxPromptCharacters + 1)
        XCTAssertThrowsError(try PromptValidation.validatedPrompt(huge)) { error in
            XCTAssertEqual(error as? AIError, .inputTooLarge)
        }
    }

    func testMaxLengthPromptSucceeds() throws {
        let exact = String(repeating: "a", count: PromptValidation.maxPromptCharacters)
        XCTAssertEqual(try PromptValidation.validatedPrompt(exact), exact)
    }

    func testHistoryIsPrefixedOnce() {
        let result = PromptValidation.promptIncludingHistory(
            history: [("user", "Hi"), ("assistant", "Hello")],
            prompt: "Again"
        )
        XCTAssertTrue(result.contains("Previous conversation:"))
        XCTAssertTrue(result.contains("user: Hi"))
        XCTAssertTrue(result.contains("assistant: Hello"))
        XCTAssertTrue(result.contains("User:\nAgain"))
    }

    func testNilHistoryReturnsPrompt() {
        XCTAssertEqual(
            PromptValidation.promptIncludingHistory(history: nil, prompt: "Hi"),
            "Hi"
        )
    }
}

final class PicoMenuLayoutTests: XCTestCase {
    func testPauseTitleToggles() {
        XCTAssertEqual(PicoMenuLayout.pauseTitle(isPaused: false), "Pause Pico")
        XCTAssertEqual(PicoMenuLayout.pauseTitle(isPaused: true), "Resume Pico")
    }

    func testSessionActionsDisabledWhenPaused() {
        XCTAssertTrue(PicoMenuLayout.sessionActionsEnabled(isPaused: false))
        XCTAssertFalse(PicoMenuLayout.sessionActionsEnabled(isPaused: true))
    }

    func testStatusTitlesIncludeResumeWhenPaused() {
        XCTAssertEqual(PicoMenuLayout.statusItemTitles(isPaused: false).first, "Ask Pico")
        XCTAssertTrue(PicoMenuLayout.statusItemTitles(isPaused: true).contains("Resume Pico"))
        XCTAssertFalse(PicoMenuLayout.statusItemTitles(isPaused: true).contains("Pause Pico"))
    }

    func testPetMenuIncludesGestures() {
        let titles = PicoMenuLayout.petMenuTitles(isPaused: false)
        XCTAssertTrue(titles.contains("Pet Pico"))
        XCTAssertTrue(titles.contains("Feed Pico"))
        XCTAssertTrue(titles.contains("Shoo Pico"))
    }
}

final class AIErrorTests: XCTestCase {
    func testFriendlyMessages() {
        XCTAssertEqual(AIError.emptyPrompt.errorDescription, "Type something first.")
        XCTAssertEqual(AIError.inputTooLarge.errorDescription, "That text is a bit too long for me. Try a shorter selection.")
        XCTAssertEqual(AIError.cancelled.errorDescription, "Cancelled.")
        XCTAssertEqual(AIError.generationFailed.errorDescription, "Hmm, I couldn’t do that.")
        XCTAssertTrue(
            AIError.unavailable(.appleIntelligenceNotEnabled).errorDescription?
                .contains("Apple Intelligence") == true
        )
        XCTAssertTrue(
            AIError.unavailable(.deviceNotEligible).errorDescription?
                .contains("Mac") == true
        )
        XCTAssertTrue(
            AIError.unavailable(.modelNotReady).errorDescription?
                .contains("ready") == true
        )
    }

    func testCaptureErrorMessages() {
        XCTAssertTrue(
            TextProcessor.CaptureError.noSelection.errorDescription?
                .contains("Select some text") == true
        )
        XCTAssertTrue(
            TextProcessor.CaptureError.accessibilityRequired.errorDescription?
                .contains("Accessibility") == true
        )
    }
}

final class TextActionCatalogTests: XCTestCase {
    func testAllActionsHaveTitlesAndSymbols() {
        XCTAssertEqual(TextAction.allCases.count, 6)
        for action in TextAction.allCases {
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.symbolName.isEmpty)
            XCTAssertEqual(action.id, action.rawValue)
        }
    }
}
