import XCTest
@testable import Pico

@MainActor
final class AIServiceTests: XCTestCase {
    func testPerformRoutesEveryTextAction() async throws {
        let mock = MockAIProvider()
        mock.generateResult = "ok"
        let service = AIService(provider: mock)

        for action in TextAction.allCases {
            let result = try await service.perform(action: action, on: "hello")
            XCTAssertEqual(result, "ok")
        }
    }

    func testGenerateErrorSurfaces() async {
        let mock = MockAIProvider()
        mock.generateError = .generationFailed
        let service = AIService(provider: mock)
        do {
            _ = try await service.perform(action: .rewrite, on: "hello")
            XCTFail("Expected failure")
        } catch let error as AIError {
            XCTAssertEqual(error, .generationFailed)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testLongTextIsProcessedInChunksAndKeepsSpacing() async throws {
        let mock = MockAIProvider()
        mock.generateResult = "X"
        let service = AIService(provider: mock)
        let paragraph = String(repeating: "word ", count: 400) // 2,000 characters
        let text = paragraph + "\n\n" + paragraph + "\n\n" + paragraph

        let result = try await service.perform(action: .fixGrammar, on: text)

        XCTAssertGreaterThan(mock.prompts.count, 1)
        XCTAssertTrue(mock.prompts.allSatisfy { $0.count <= AIService.maxChunkCharacters })
        XCTAssertTrue(result.contains("\n\n"))
    }

    func testTextOverTheLimitIsRejected() async {
        let service = AIService(provider: MockAIProvider())
        let huge = String(repeating: "a", count: PromptValidation.maxPromptCharacters + 1)
        do {
            _ = try await service.perform(action: .improve, on: huge)
            XCTFail("Expected failure")
        } catch let error as AIError {
            XCTAssertEqual(error, .inputTooLarge)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testWhitespaceOnlyChunksSkipTheModel() async throws {
        let mock = MockAIProvider()
        let service = AIService(provider: mock)
        let result = try await service.perform(action: .rewrite, on: "   ")
        XCTAssertEqual(result, "   ")
        XCTAssertTrue(mock.prompts.isEmpty)
    }
}

final class TextChunkerTests: XCTestCase {
    func testShortTextIsOneChunk() {
        XCTAssertEqual(TextChunker.split("hello", limit: 100), ["hello"])
    }

    func testChunksRoundTripAndRespectLimit() {
        let sentence = "This is a sentence. "
        let text = String(repeating: sentence, count: 50) + "\n\n" + String(repeating: "z", count: 700)
        let chunks = TextChunker.split(text, limit: 200)
        XCTAssertEqual(chunks.joined(), text)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 200 })
        XCTAssertGreaterThan(chunks.count, 3)
    }

    func testPrefersParagraphBoundaries() {
        let text = "First paragraph here.\n\nSecond paragraph here.\n\nThird."
        let chunks = TextChunker.split(text, limit: 30)
        XCTAssertEqual(chunks.joined(), text)
        XCTAssertEqual(chunks.first, "First paragraph here.\n\n")
    }

    func testTrailingWhitespace() {
        XCTAssertEqual(TextChunker.trailingWhitespace(of: "abc \n"), " \n")
        XCTAssertEqual(TextChunker.trailingWhitespace(of: "abc"), "")
    }
}

final class TextDiffTests: XCTestCase {
    func testTokensAlternateWordsAndWhitespace() {
        XCTAssertEqual(TextDiff.tokens("a  b\nc"), ["a", "  ", "b", "\n", "c"])
        XCTAssertEqual(TextDiff.tokens(""), [])
    }

    func testOnlyChangedWordsAreMarked() {
        let diff = TextDiff.compare(
            original: "This sentance has a error",
            suggested: "This sentence has an error"
        )
        let marked = diff.inserted.sorted().map { diff.tokens[$0] }
        XCTAssertEqual(marked, ["sentence", "an"])
    }

    func testIdenticalTextHasNoChanges() {
        XCTAssertTrue(TextDiff.compare(original: "same text", suggested: "same text").inserted.isEmpty)
    }
}
