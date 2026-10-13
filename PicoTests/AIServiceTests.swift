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
        XCTAssertEqual(mock.lastPrompts.count, TextAction.allCases.count)
        XCTAssertEqual(mock.lastInstructions.count, TextAction.allCases.count)
        XCTAssertTrue(mock.lastInstructions.contains { $0.contains("bullet") })
        XCTAssertTrue(mock.lastInstructions.contains { $0.contains("Spanish") })
        XCTAssertTrue(mock.lastInstructions.contains { $0.contains("reply") })
    }

    func testCustomInstructionIsPassedThrough() async throws {
        let mock = MockAIProvider()
        mock.generateResult = "ok"
        let service = AIService(provider: mock)
        let result = try await service.performCustom(instruction: "Make it warmer", on: "hello")
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(mock.lastPrompts, ["hello"])
        XCTAssertTrue(mock.lastInstructions.first?.contains("Make it warmer") == true)
        XCTAssertTrue(mock.lastInstructions.first?.contains("Return only the result text") == true)
    }

    func testGenerateErrorSurfaces() async {
        let mock = MockAIProvider()
        mock.generateError = .generationFailed
        let service = AIService(provider: mock)
        do {
            _ = try await service.rewrite("hello")
            XCTFail("Expected failure")
        } catch let error as AIError {
            XCTAssertEqual(error, .generationFailed)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testAskUsesStreamChunks() async throws {
        let mock = MockAIProvider()
        mock.streamChunks = ["A", "AB"]
        let service = AIService(provider: mock)
        var last = ""
        for try await partial in service.ask(prompt: "Hi", conversationID: UUID()) {
            last = partial
        }
        XCTAssertEqual(last, "AB")
    }
}
