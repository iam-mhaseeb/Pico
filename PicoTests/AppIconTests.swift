import CoreGraphics
import Foundation
import ImageIO
import XCTest

/// Guards against shipping an app with no launcher icon (the asset catalog slots existed
/// once without any image files in them).
final class AppIconTests: XCTestCase {
    private var iconSetURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // PicoTests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent("Pico/Resources/Assets.xcassets/AppIcon.appiconset")
    }

    func testEveryIconSlotHasAnImageOfTheRightSize() throws {
        let contents = iconSetURL.appendingPathComponent("Contents.json")
        let data = try Data(contentsOf: contents)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let images = try XCTUnwrap(json["images"] as? [[String: Any]])
        XCTAssertEqual(images.count, 10, "macOS needs 16, 32, 128, 256 and 512pt at 1x and 2x")

        for entry in images {
            let size = try XCTUnwrap(entry["size"] as? String)
            let scale = try XCTUnwrap(entry["scale"] as? String)
            let filename = try XCTUnwrap(entry["filename"] as? String, "\(size) \(scale) has no image file")

            let points = try XCTUnwrap(Int(size.split(separator: "x")[0]))
            let multiplier = scale == "2x" ? 2 : 1
            let expectedPixels = points * multiplier

            let url = iconSetURL.appendingPathComponent(filename)
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), "\(filename) is missing")
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(image.width, expectedPixels, "\(filename) width")
            XCTAssertEqual(image.height, expectedPixels, "\(filename) height")
        }
    }
}
