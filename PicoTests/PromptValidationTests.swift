import CoreGraphics
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

    func testStatusMenuOmitsPetGestures() {
        let titles = PicoMenuLayout.statusItemTitles(isPaused: false)
        XCTAssertFalse(titles.contains("Pet Pico"))
        XCTAssertFalse(titles.contains("Feed Pico"))
        XCTAssertFalse(titles.contains("Shoo Pico"))
        XCTAssertFalse(titles.contains("Drop toy"))
        XCTAssertEqual(titles, [
            "Ask Pico",
            "Text Actions",
            "Undo last rewrite",
            "History",
            "Settings…",
            "Pause Pico",
            "Quit Pico"
        ])
    }
}

final class MenuBarPanelPlacementTests: XCTestCase {
    func testPanelOpensUnderTheMenuBarIcon() {
        let anchor = CGRect(x: 900, y: 800, width: 24, height: 24)
        let size = CGSize(width: 380, height: 420)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 820)
        let origin = MenuBarPanelPlacement.origin(
            anchor: anchor,
            panelSize: size,
            visibleFrame: visible,
            gap: 12
        )
        XCTAssertEqual(origin.x, anchor.midX - size.width / 2, accuracy: 0.1)
        XCTAssertEqual(origin.y, anchor.minY - size.height - 12, accuracy: 0.1)
        XCTAssertLessThan(origin.y + size.height, anchor.minY)
    }

    func testPanelStaysInsideTheVisibleScreen() {
        let anchor = CGRect(x: 1400, y: 860, width: 24, height: 24)
        let size = CGSize(width: 380, height: 420)
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 820)
        let origin = MenuBarPanelPlacement.origin(
            anchor: anchor,
            panelSize: size,
            visibleFrame: visible,
            gap: 12
        )
        XCTAssertGreaterThanOrEqual(origin.x, visible.minX + 4)
        XCTAssertGreaterThanOrEqual(origin.y, visible.minY + 4)
        XCTAssertLessThanOrEqual(origin.x + size.width, visible.maxX - 4)
        XCTAssertLessThanOrEqual(origin.y + size.height, visible.maxY - 4)
    }

    func testPanelClampsToTheLeftAndBottomEdges() {
        let visible = CGRect(x: 20, y: 40, width: 800, height: 500)
        let origin = MenuBarPanelPlacement.origin(
            anchor: CGRect(x: 0, y: 30, width: 10, height: 10),
            panelSize: CGSize(width: 300, height: 400),
            visibleFrame: visible,
            gap: 8
        )
        XCTAssertEqual(origin.x, visible.minX + 4, accuracy: 0.1)
        XCTAssertEqual(origin.y, visible.minY + 4, accuracy: 0.1)
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
        XCTAssertEqual(TextAction.allCases.count, 9)
        for action in TextAction.allCases {
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.symbolName.isEmpty)
            XCTAssertEqual(action.id, action.rawValue)
        }
    }
}
