import XCTest
@testable import Pico

final class MacAIProviderLogicTests: XCTestCase {
    func testCancelDoesNotRequireSessionID() {
        let provider = MacAIProvider()
        provider.cancel(sessionID: UUID())
        // Should not crash; session lifecycle tested via mock provider in Ask tests.
    }
}
