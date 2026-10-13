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

    func testCustomInstructionShowsPreview() async {
        viewModel.apply(capture: sampleCapture("hello"))
        viewModel.customInstruction = "  Make this a Slack reply  "
        await viewModel.runCustom()
        XCTAssertEqual(viewModel.phase, .preview)
        XCTAssertEqual(viewModel.suggestedText, "Improved text")
        XCTAssertTrue(mockProvider.lastInstructions.contains { $0.contains("Slack reply") })
        XCTAssertTrue(mockProvider.lastPrompts.contains("hello"))
    }

    func testBlankCustomInstructionDoesNothing() async {
        viewModel.apply(capture: sampleCapture("hello"))
        viewModel.customInstruction = "   "
        await viewModel.runCustom()
        XCTAssertEqual(viewModel.phase, .chooseAction)
        XCTAssertTrue(mockProvider.lastInstructions.isEmpty)
    }

    func testCustomCancelReturnsToTheList() async {
        mockProvider.generateError = .cancelled
        viewModel.apply(capture: sampleCapture("hello"))
        viewModel.customInstruction = "Shorten a lot"
        await viewModel.runCustom()
        XCTAssertEqual(viewModel.phase, .chooseAction)
    }

    func testCustomFailureShowsError() async {
        mockProvider.generateError = .generationFailed
        viewModel.apply(capture: sampleCapture("hello"))
        viewModel.customInstruction = "Translate"
        await viewModel.runCustom()
        if case .error = viewModel.phase {
        } else {
            XCTFail("Expected error phase")
        }
    }

    func testCopyKeepsTheSuggestionAndSkipsClipboardRestore() {
        let clipboard = ClipboardManager()
        clipboard.writeString("previous")
        let snapshot = clipboard.snapshot()
        let localProcessor = TextProcessor(
            accessibility: accessibility,
            clipboard: clipboard,
            aiService: AIService(provider: mockProvider),
            keyEvents: keyEvents
        )
        let local = TextActionMenuViewModel(processor: localProcessor)
        local.apply(capture: TextProcessor.CaptureResult(
            text: "selection",
            strategy: .clipboard,
            selectionRect: nil,
            pasteboardSnapshot: snapshot,
            sourceAppPID: nil
        ))
        local.suggestedText = "rewritten"
        local.copySuggestion()
        local.abandon()
        XCTAssertEqual(clipboard.readString(), "rewritten")
    }

    func testInsertRecordsUndoAndUndoRestoresOriginal() async {
        accessibility.setSelectedTextResult = true
        viewModel.apply(capture: sampleCapture("hello", strategy: .accessibility))
        viewModel.suggestedText = "done"
        XCTAssertFalse(processor.canUndo)
        XCTAssertTrue(await viewModel.insert())
        XCTAssertTrue(processor.canUndo)
        try? await processor.undoLast()
        XCTAssertEqual(accessibility.lastSetText, "hello")
        XCTAssertFalse(processor.canUndo)
    }

    func testUndoWithoutARewriteFails() async {
        do {
            try await processor.undoLast()
            XCTFail("Expected failure")
        } catch let error as TextReplacementError {
            XCTAssertEqual(error, .replaceFailed)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testInsertPetStates() async {
        var states: [PetState] = []
        viewModel.onPetState = { states.append($0) }
        viewModel.apply(capture: sampleCapture("hello", strategy: .accessibility))
        await viewModel.run(.reply)
        accessibility.setSelectedTextResult = true
        viewModel.suggestedText = "reply"
        _ = await viewModel.insert()
        XCTAssertEqual(states.first, .listening)
        XCTAssertTrue(states.contains(.thinking))
        XCTAssertTrue(states.contains(.curious))
        XCTAssertEqual(states.last, .celebrating)
    }

    func testRunFailureSetsErrorPetState() async {
        mockProvider.generateError = .generationFailed
        var pet: PetState?
        viewModel.onPetState = { pet = $0 }
        viewModel.apply(capture: sampleCapture("hello"))
        await viewModel.run(.bullets)
        XCTAssertEqual(pet, .error)
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
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.symbolName.isEmpty)
        }
        let symbols = Set(TextAction.allCases.map(\.symbolName))
        XCTAssertEqual(symbols.count, TextAction.allCases.count)
    }

    private func sampleCapture(
        _ text: String,
        strategy: TextReplacementStrategy = .clipboard
    ) -> TextProcessor.CaptureResult {
        TextProcessor.CaptureResult(
            text: text,
            strategy: strategy,
            selectionRect: nil,
            pasteboardSnapshot: nil,
            sourceAppPID: nil
        )
    }
}
