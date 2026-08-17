import XCTest
@testable import Pico

@MainActor
final class TextActionMenuViewModelTests: XCTestCase {
    private var mockProvider: MockAIProvider!
    private var accessibility: MockAccessibility!
    private var keyEvents: MockKeyEvents!
    private var processor: TextProcessor!
    private var viewModel: TextActionMenuViewModel!

    override func setUp() async throws {
        mockProvider = MockAIProvider()
        mockProvider.generateResult = "Improved text"
        accessibility = MockAccessibility()
        keyEvents = MockKeyEvents()
        processor = TextProcessor(
            accessibility: accessibility,
            clipboard: ClipboardManager(),
            aiService: AIService(provider: mockProvider),
            keyEvents: keyEvents
        )
        viewModel = TextActionMenuViewModel(processor: processor)
    }

    func testApplyCaptureSetsChooseActionPhase() {
        let capture = TextProcessor.CaptureResult(
            text: "hello",
            strategy: .clipboard,
            selectionRect: CGRect(x: 10, y: 20, width: 100, height: 20),
            pasteboardSnapshot: nil,
            sourceAppPID: nil
        )
        viewModel.apply(capture: capture)

        XCTAssertEqual(viewModel.originalText, "hello")
        XCTAssertEqual(viewModel.phase, .chooseAction)
        XCTAssertEqual(viewModel.selectionRect?.width, 100)
    }

    func testApplyNoSelectionError() {
        viewModel.apply(error: .noSelection)
        XCTAssertEqual(viewModel.phase, .emptySelection)
    }

    func testApplyAccessibilityRequiredError() {
        viewModel.apply(error: .accessibilityRequired)
        XCTAssertEqual(viewModel.phase, .permissionRequired)
    }

    func testApplyClipboardFailedError() {
        viewModel.apply(error: .clipboardFailed)
        if case .error = viewModel.phase {
            // expected
        } else {
            XCTFail("Expected error phase")
        }
    }

    func testRunTransformShowsPreview() async {
        viewModel.apply(capture: TextProcessor.CaptureResult(
            text: "hello",
            strategy: .clipboard,
            selectionRect: nil,
            pasteboardSnapshot: nil,
            sourceAppPID: nil
        ))
        await viewModel.run(.rewrite)
        XCTAssertEqual(viewModel.phase, .preview)
        XCTAssertEqual(viewModel.suggestedText, "Improved text")
    }

    func testAbandonRestoresClipboard() {
        let clipboard = ClipboardManager()
        clipboard.writeString("original")
        let snapshot = clipboard.snapshot()
        clipboard.writeString("selection copy")

        viewModel.apply(capture: TextProcessor.CaptureResult(
            text: "selection copy",
            strategy: .clipboard,
            selectionRect: nil,
            pasteboardSnapshot: snapshot,
            sourceAppPID: nil
        ))
        viewModel.abandon()

        XCTAssertEqual(clipboard.readString(), "original")
    }

    func testInsertSuccessFinishes() async {
        var finished = false
        viewModel.onFinished = { finished = true }
        accessibility.setSelectedTextResult = true
        viewModel.apply(capture: TextProcessor.CaptureResult(
            text: "hello",
            strategy: .accessibility,
            selectionRect: nil,
            pasteboardSnapshot: nil,
            sourceAppPID: nil
        ))
        await viewModel.run(.rewrite)
        viewModel.suggestedText = "done"
        let inserted = await viewModel.insert()
        XCTAssertTrue(inserted)
        XCTAssertTrue(finished)
        XCTAssertEqual(accessibility.lastSetText, "done")
        XCTAssertEqual(keyEvents.pasteCount, 0)
    }

    func testEmptySelectionUsesCuriousPetState() {
        var pet: PetState?
        viewModel.onPetState = { pet = $0 }
        viewModel.apply(error: .noSelection)
        XCTAssertEqual(viewModel.phase, .emptySelection)
        XCTAssertEqual(pet, .curious)
    }

    func testTransformCancelReturnsToChooseAction() async {
        mockProvider.generateError = .cancelled
        viewModel.apply(capture: TextProcessor.CaptureResult(
            text: "hello",
            strategy: .clipboard,
            selectionRect: nil,
            pasteboardSnapshot: nil,
            sourceAppPID: nil
        ))
        await viewModel.run(.rewrite)
        XCTAssertEqual(viewModel.phase, .chooseAction)
    }

    func testAllActionsReachPreview() async {
        viewModel.apply(capture: TextProcessor.CaptureResult(
            text: "hello",
            strategy: .clipboard,
            selectionRect: nil,
            pasteboardSnapshot: nil,
            sourceAppPID: nil
        ))
        for action in TextAction.allCases {
            await viewModel.run(action)
            XCTAssertEqual(viewModel.phase, .preview, "Failed for \(action.title)")
        }
    }
}
