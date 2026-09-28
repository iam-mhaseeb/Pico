import CoreGraphics
import XCTest
@testable import Pico

final class ScreenIntentTests: XCTestCase {
    func testLookPhrases() {
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("What's on my screen?"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Look at the screen and summarize"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("What do you see?"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Describe this window"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Take a screenshot of that"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Read the screen and follow the instructions"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Follow the instructions on my screen"))
    }

    func testActionPhrases() {
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Click the Submit button"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Clicking Save now"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Type into the search field"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Fill out this form"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Press the return key"))
        XCTAssertTrue(ScreenIntent.requestsScreenHelp("Hit enter"))
    }

    func testOrdinaryChatDoesNotTrigger() {
        XCTAssertFalse(ScreenIntent.requestsScreenHelp("What's the capital of France?"))
        XCTAssertFalse(ScreenIntent.requestsScreenHelp("Rewrite this paragraph"))
        XCTAssertFalse(ScreenIntent.requestsScreenHelp("How do I impress the interviewer?"))
        XCTAssertFalse(ScreenIntent.requestsScreenHelp(""))
        XCTAssertFalse(ScreenIntent.requestsScreenHelp("   "))
        XCTAssertFalse(ScreenIntent.requestsScreenHelp("Follow the instructions"))
    }
}

final class ScreenDescriptionTests: XCTestCase {
    func testNodeMatchingPrefersExactThenId() {
        let snapshot = AccessibilitySnapshot(
            appName: "Safari",
            pid: 1,
            windowTitle: "Inbox",
            nodes: [
                AXNode(id: 12, role: "button", title: "Submit", value: nil, enabled: true, secure: false),
                AXNode(id: 13, role: "button", title: "Submit all", value: nil, enabled: true, secure: false),
                AXNode(id: 14, role: "textField", title: "Password", value: nil, enabled: true, secure: true)
            ]
        )
        XCTAssertEqual(snapshot.node(matching: "#12")?.title, "Submit")
        XCTAssertEqual(snapshot.node(matching: "Submit")?.id, 12)
        XCTAssertEqual(snapshot.node(matching: "submit all")?.id, 13)
        XCTAssertNil(snapshot.node(matching: "   "))
        XCTAssertTrue(snapshot.node(matching: "Password")?.secure == true)
    }

    func testInteractiveRolesUseStringNamesIncludingLink() {
        XCTAssertTrue(AXRoleName.isInteractive("AXLink"))
        XCTAssertTrue(AXRoleName.isInteractive("AXButton"))
        XCTAssertTrue(AXRoleName.isInteractive("AXSecureTextField"))
        XCTAssertTrue(AXRoleName.isReadableText("AXHeading"))
        XCTAssertFalse(AXRoleName.isInteractive("AXGroup"))
        XCTAssertFalse(AXRoleName.isReadableText("AXButton"))
    }

    func testComposeIncludesAXAndOCR() {
        let text = ScreenDescription.compose(
            appName: "Notes",
            ax: "- button \"Save\" #1",
            ocr: "[0.10,0.20,0.15,0.04] Save"
        )
        XCTAssertTrue(text.contains("Frontmost app: Notes"))
        XCTAssertTrue(text.contains("Save"))
        XCTAssertTrue(text.contains("0.10"))
    }

    func testTruncateAddsEllipsis() {
        let text = ScreenDescription.truncate(String(repeating: "a", count: 20), limit: 8)
        XCTAssertTrue(text.hasSuffix("\n…"))
        XCTAssertEqual(text.count, 10)
    }

    func testQuartzPointUsesTopLeftNormalized() {
        let bounds = CGRect(x: 100, y: 50, width: 200, height: 400)
        let point = ScreenCoordinates.quartzPoint(normalizedX: 0.5, normalizedY: 0.25, displayBounds: bounds)
        XCTAssertEqual(point.x, 200, accuracy: 0.01)
        XCTAssertEqual(point.y, 150, accuracy: 0.01)
    }

    func testOCRLineFormatsBox() {
        let line = OCRLine(text: "Hello", x: 0.1, y: 0.2, width: 0.3, height: 0.05)
        XCTAssertEqual(line.formatted, "[0.10,0.20,0.30,0.05] Hello")
    }
}

final class ScreenKeyPressParserTests: XCTestCase {
    func testParsesNamedKeysAndModifiers() throws {
        let enter = try ScreenKeyPressParser.parse("return")
        XCTAssertEqual(enter.keyCode, ScreenKeyPressParser.keyCode(for: "return"))
        XCTAssertTrue(enter.flags.isEmpty)

        let copy = try ScreenKeyPressParser.parse("command+c")
        XCTAssertEqual(copy.keyCode, ScreenKeyPressParser.keyCode(for: "c"))
        XCTAssertTrue(copy.flags.contains(.maskCommand))
    }

    func testUnknownKeyFails() {
        XCTAssertThrowsError(try ScreenKeyPressParser.parse("command+foo")) { error in
            XCTAssertEqual(error as? ScreenKeyPressParser.ParseError, .unknownKey("foo"))
        }
        XCTAssertThrowsError(try ScreenKeyPressParser.parse("   ")) { error in
            XCTAssertEqual(error as? ScreenKeyPressParser.ParseError, .empty)
        }
    }
}
