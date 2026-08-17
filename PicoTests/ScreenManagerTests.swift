import XCTest
import AppKit
@testable import Pico

final class ScreenManagerTests: XCTestCase {
    func testCocoaRectConvertsTopLeftToBottomLeft() {
        let unionHeight: CGFloat = 1200
        let cgBounds = CGRect(x: 100, y: 200, width: 300, height: 50)
        // Simulate conversion when global desktop height is known
        let expectedY = unionHeight - cgBounds.origin.y - cgBounds.height
        let converted = ScreenManager.cocoaRect(fromCGWindowBounds: cgBounds)
        XCTAssertEqual(converted.origin.x, 100)
        XCTAssertEqual(converted.width, 300)
        XCTAssertEqual(converted.height, 50)
        // Y depends on actual screen union — at least verify it's not equal to CG Y
        XCTAssertNotEqual(converted.origin.y, cgBounds.origin.y)
        if unionHeight > 0 {
            // When screens exist, union height matches real desktop
            let realUnion = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }.maxY
            if realUnion > 0 {
                XCTAssertEqual(converted.origin.y, realUnion - 200 - 50, accuracy: 0.5)
            }
        }
    }

    func testClampOriginKeepsPanelInsideVisibleFrame() throws {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("No screen")
        }
        let size = CGSize(width: 320, height: 300)
        let visible = screen.visibleFrame
        let farOutside = CGPoint(x: visible.minX - 500, y: visible.minY - 500)
        let clamped = ScreenManager.clampOrigin(farOutside, size: size, on: screen)
        XCTAssertGreaterThanOrEqual(clamped.x, visible.minX + 4)
        XCTAssertGreaterThanOrEqual(clamped.y, visible.minY + 4)
        XCTAssertLessThanOrEqual(clamped.x + size.width, visible.maxX - 4)
        XCTAssertLessThanOrEqual(clamped.y + size.height, visible.maxY - 4)
    }

    func testDefaultPetOriginIsOnScreen() throws {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("No screen")
        }
        let origin = ScreenManager.defaultPetOrigin(on: screen)
        let petRect = CGRect(origin: origin, size: CGSize(width: PicoTheme.petSize, height: PicoTheme.petSize))
        XCTAssertTrue(screen.visibleFrame.contains(petRect))
    }
}
