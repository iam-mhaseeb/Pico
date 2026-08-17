import XCTest
@testable import Pico

@MainActor
final class TextProcessorCaptureTests: XCTestCase {
    private var accessibility: MockAccessibility!
    private var clipboard: ClipboardManager!
    private var keyEvents: MockKeyEvents!
    private var processor: TextProcessor!
    private var previousClipboard: PasteboardSnapshot!

    override func setUp() async throws {
        accessibility = MockAccessibility()
        clipboard = ClipboardManager()
        keyEvents = MockKeyEvents()
        previousClipboard = clipboard.snapshot()
        processor = TextProcessor(
            accessibility: accessibility,
            clipboard: clipboard,
            aiService: AIService(provider: MockAIProvider()),
            keyEvents: keyEvents
        )
    }

    override func tearDown() {
        clipboard.restore(previousClipboard)
        super.tearDown()
    }

    func testCaptureUsesAccessibilityTextWithoutCopy() async throws {
        accessibility.selectedTextValue = "from AX"
        accessibility.selectedRect = CGRect(x: 1, y: 2, width: 3, height: 4)

        let capture = try await processor.captureSelection()

        XCTAssertEqual(capture.text, "from AX")
        XCTAssertEqual(capture.strategy, .accessibility)
        XCTAssertEqual(capture.selectionRect?.width, 3)
        XCTAssertEqual(keyEvents.copyCount, 0)
        XCTAssertNil(capture.pasteboardSnapshot)
    }

    func testCaptureRequiresAccessibilityWhenUntrustedAndNoAXText() async {
        accessibility.isTrusted = false
        accessibility.selectedTextValue = nil

        do {
            _ = try await processor.captureSelection()
            XCTFail("Expected error")
        } catch let error as TextProcessor.CaptureError {
            XCTAssertEqual(error, .accessibilityRequired)
        } catch {
            XCTFail("Unexpected \(error)")
        }
        XCTAssertEqual(keyEvents.copyCount, 0)
    }

    func testCaptureNoSelectionWhenCopyDoesNotChangePasteboard() async {
        accessibility.isTrusted = true
        accessibility.selectedTextValue = nil
        clipboard.writeString("untouched")

        do {
            _ = try await processor.captureSelection()
            XCTFail("Expected noSelection")
        } catch let error as TextProcessor.CaptureError {
            XCTAssertEqual(error, .noSelection)
        } catch {
            XCTFail("Unexpected \(error)")
        }
        XCTAssertEqual(keyEvents.copyCount, 1)
        XCTAssertEqual(clipboard.readString(), "untouched")
    }

    func testCaptureClipboardStrategyWhenCopyChangesPasteboard() async throws {
        accessibility.isTrusted = true
        accessibility.selectedTextValue = nil
        clipboard.writeString("before")
        keyEvents.onCopy = { [clipboard] in
            clipboard?.writeString("selected text")
        }

        let capture = try await processor.captureSelection()

        XCTAssertEqual(capture.text, "selected text")
        XCTAssertEqual(capture.strategy, .clipboard)
        XCTAssertNotNil(capture.pasteboardSnapshot)
        XCTAssertEqual(keyEvents.copyCount, 1)
    }

    func testCaptureWhitespaceOnlyIsNoSelection() async {
        accessibility.isTrusted = true
        accessibility.selectedTextValue = nil
        clipboard.writeString("before")
        keyEvents.onCopy = { [clipboard] in
            clipboard?.writeString("   \n")
        }

        do {
            _ = try await processor.captureSelection()
            XCTFail("Expected noSelection")
        } catch let error as TextProcessor.CaptureError {
            XCTAssertEqual(error, .noSelection)
        } catch {
            XCTFail("Unexpected \(error)")
        }
        XCTAssertEqual(clipboard.readString(), "before")
    }

    func testInsertPrefersAccessibilitySetSelectedText() async throws {
        accessibility.setSelectedTextResult = true
        try await processor.insert(
            result: "inserted",
            strategy: .accessibility,
            pasteboardSnapshot: nil,
            sourceAppPID: nil
        )
        XCTAssertEqual(accessibility.lastSetText, "inserted")
        XCTAssertEqual(keyEvents.pasteCount, 0)
    }

    func testInsertFallsBackToClipboardWhenAccessibilitySetFails() async throws {
        accessibility.setSelectedTextResult = false
        clipboard.writeString("original")
        let snapshot = clipboard.snapshot()

        try await processor.insert(
            result: "pasted",
            strategy: .accessibility,
            pasteboardSnapshot: snapshot,
            sourceAppPID: nil
        )

        XCTAssertEqual(keyEvents.pasteCount, 1)
        XCTAssertEqual(clipboard.readString(), "original")
    }
}

extension TextProcessor.CaptureError: Equatable {}
