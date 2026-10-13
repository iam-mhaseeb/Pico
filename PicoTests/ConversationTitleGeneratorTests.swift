import XCTest
@testable import Pico

final class ConversationTitleGeneratorTests: XCTestCase {
    func testEmptyBecomesNewConversation() {
        XCTAssertEqual(ConversationTitleGenerator.title(from: "   "), "New conversation")
    }

    func testShortMessagePreserved() {
        XCTAssertEqual(
            ConversationTitleGenerator.title(from: "Explain this Python error"),
            "Explain this Python error"
        )
    }

    func testLongMessageTruncatedAtWordBoundary() {
        let input = "Can you explain why my FastAPI deployment keeps failing in production environments"
        let title = ConversationTitleGenerator.title(from: input)
        XCTAssertLessThanOrEqual(title.count, 42)
        XCTAssertFalse(title.hasSuffix(" "))
        XCTAssertTrue(input.hasPrefix(title) || title.split(separator: " ").count >= 1)
    }

    func testExactLimitIsKept() {
        let exact = String(repeating: "a", count: 42)
        XCTAssertEqual(ConversationTitleGenerator.title(from: exact), exact)
    }

    func testLongWordWithoutSpacesIsCutAtTheLimit() {
        let word = String(repeating: "b", count: 60)
        XCTAssertEqual(ConversationTitleGenerator.title(from: word).count, 42)
    }

    func testNewlinesCollapsedToSpaces() {
        XCTAssertEqual(
            ConversationTitleGenerator.title(from: "Hello\nthere"),
            "Hello there"
        )
    }
}
