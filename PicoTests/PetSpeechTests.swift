import XCTest
@testable import Pico

final class PetSpeechTests: XCTestCase {
    func testLinesExistForAllKinds() {
        for kind in [PetSpeechKind.pet, .feed, .shoo, .greeting] {
            let line = PetSpeechLines.line(for: kind)
            XCTAssertFalse(line.isEmpty)
        }
    }
}
