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
