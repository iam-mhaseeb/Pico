import XCTest
@testable import Pico
import AppKit

final class PetEdgeSnapTests: XCTestCase {
    func testSnapDisabledKeepsClampedFreePosition() {
        let size = CGSize(width: 56, height: 56)
        let origin = CGPoint(x: 200, y: 200)
        let result = PetEdgeSnap.snapOrigin(for: size, from: origin, enabled: false)
        XCTAssertEqual(result.edge, .free)
        XCTAssertEqual(result.origin.x, origin.x, accuracy: 0.5)
        XCTAssertEqual(result.origin.y, origin.y, accuracy: 0.5)
    }

    func testSnapStaysOnIntersectingScreen() {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("No screen available")
        }
        let size = CGSize(width: 56, height: 56)
        let visible = screen.visibleFrame
        let origin = CGPoint(x: visible.midX, y: visible.minY + 40)
        let result = PetEdgeSnap.snapOrigin(for: size, from: origin, enabled: true)
        XCTAssertEqual(ScreenManager.displayID(for: result.screen), ScreenManager.displayID(for: screen))
        XCTAssertTrue(result.screen.frame.intersects(NSRect(origin: result.origin, size: size)))
    }
}
