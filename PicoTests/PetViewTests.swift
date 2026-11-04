import SwiftUI
import XCTest
@testable import Pico

@MainActor
final class PetViewTests: XCTestCase {
    func testEveryStateRendersAtMenuBarAndPanelSizes() {
        for state in PetState.allCases {
            for size in [18.0, 30.0, 72.0] {
                let renderer = ImageRenderer(
                    content: PetFaceView(state: state, size: size, pauseAnimation: true)
                )
                renderer.scale = 2
                XCTAssertNotNil(renderer.cgImage, "\(state) failed to render at \(size)pt")
            }
        }
    }
}
