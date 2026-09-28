import XCTest
@testable import Pico

final class PetSpeechTests: XCTestCase {
    func testLinesExistForAllKinds() {
        for persona in PetPersona.allCases {
            for kind in PetSpeechKind.allCases {
                let line = PetSpeechLines.line(for: kind, persona: persona)
                XCTAssertFalse(line.isEmpty)
            }
        }
    }
}
