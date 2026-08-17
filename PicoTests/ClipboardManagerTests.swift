import XCTest
@testable import Pico

@MainActor
final class ClipboardManagerTests: XCTestCase {
    func testSnapshotAndRestoreRoundTrip() {
        let manager = ClipboardManager()
        manager.writeString("pico-test-string")
        let snapshot = manager.snapshot()

        manager.writeString("changed")
        XCTAssertEqual(manager.readString(), "changed")

        manager.restore(snapshot)
        XCTAssertEqual(manager.readString(), "pico-test-string")
    }

    func testRestoreEmptySnapshotClearsPasteboard() {
        let manager = ClipboardManager()
        manager.writeString("something")
        let empty = PasteboardSnapshot(items: [])
        manager.restore(empty)
        XCTAssertNil(manager.readString())
    }
}

@MainActor
final class TextProcessorClipboardTests: XCTestCase {
    func testCancelClipboardRestore() {
        let clipboard = ClipboardManager()
        clipboard.writeString("before")
        let snapshot = clipboard.snapshot()
        clipboard.writeString("after")

        let processor = TextProcessor(
            accessibility: MockAccessibility(),
            clipboard: clipboard,
            aiService: AIService(provider: MockAIProvider()),
            keyEvents: MockKeyEvents()
        )
        processor.cancelClipboardRestore(snapshot)
        XCTAssertEqual(clipboard.readString(), "before")
    }
}
