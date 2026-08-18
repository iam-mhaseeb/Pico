import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import XCTest
@testable import Pico

@MainActor
private final class MockScreenCapturer: ScreenCapturing {
    var error: Error?
    var captureCount = 0

    func captureDisplay(
        displayID: CGDirectDisplayID,
        excludingBundleIDs: Set<String>
    ) async throws -> CapturedScreen {
        captureCount += 1
        if let error { throw error }
        return CapturedScreen(
            image: ScreenTestImage.tiny(),
            displayBounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
            displayID: displayID
        )
    }
}

private struct MockOCR: ScreenOCRProviding {
    var canned: [OCRLine] = [
        OCRLine(text: "Submit", x: 0.8, y: 0.9, width: 0.1, height: 0.05)
    ]

    func lines(in image: CGImage, maxLines: Int) -> [OCRLine] {
        Array(canned.prefix(maxLines))
    }
}

@MainActor
private final class MockAXSnapshotter: AXSnapshotProviding {
    func snapshot(pid: pid_t, appName: String) -> (AccessibilitySnapshot, AXElementMap) {
        let snapshot = AccessibilitySnapshot(
            appName: appName,
            pid: pid,
            windowTitle: "Home",
            nodes: [
                AXNode(id: 1, role: "button", title: "Submit", value: nil, enabled: true, secure: false)
            ]
        )
        return (snapshot, AXElementMap())
    }
}

@MainActor
private final class MockScreenActions: ScreenActing {
    var typed: [String] = []
    var keys: [String] = []
    var clicks: [CGPoint] = []

    func press(element: AXUIElement) -> Bool { true }
    func focus(element: AXUIElement) -> Bool { true }
    func isSecure(element: AXUIElement) -> Bool { false }
    func typeText(_ text: String) { typed.append(text) }
    func pressKey(_ spec: String) throws { keys.append(spec) }
    func clickQuartz(point: CGPoint) { clicks.append(point) }
}

private final class MockScreenPermission: ScreenPermissionChecking {
    var hasScreenRecording = true
    func requestScreenRecording() -> Bool { hasScreenRecording }
}

private enum ScreenTestImage {
    static func tiny() -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 32,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return context.makeImage()!
    }
}

@MainActor
final class ScreenAgentTests: XCTestCase {
    private var capturer: MockScreenCapturer!
    private var actions: MockScreenActions!
    private var permission: MockScreenPermission!
    private var agent: ScreenAgent!

    override func setUp() async throws {
        capturer = MockScreenCapturer()
        actions = MockScreenActions()
        permission = MockScreenPermission()
        agent = ScreenAgent(
            capturer: capturer,
            ocr: MockOCR(),
            ax: MockAXSnapshotter(),
            actions: actions,
            permission: permission,
            accessibilityTrusted: { true }
        )
    }

    func testLookIsGatedUntilTurnEnabled() async {
        let denied = await agent.look()
        XCTAssertTrue(denied.contains("Screen help is off"))
        XCTAssertEqual(capturer.captureCount, 0)

        agent.beginTurn(enabled: true)
        let description = await agent.look()
        XCTAssertTrue(description.contains("Submit"))
        XCTAssertEqual(capturer.captureCount, 1)
        XCTAssertNotNil(agent.consumeTurnContext())
    }

    func testLookReportsMissingScreenRecording() async {
        permission.hasScreenRecording = false
        agent.beginTurn(enabled: true)
        let message = await agent.look()
        XCTAssertTrue(message.contains("Screen Recording"))
        XCTAssertTrue(agent.permissionNeeded)
        XCTAssertEqual(capturer.captureCount, 0)
    }

    func testClickAtIsGatedAndThenClicks() async {
        let denied = await agent.clickAt(x: 0.5, y: 0.5)
        XCTAssertTrue(denied.contains("Screen help is off"))
        XCTAssertTrue(actions.clicks.isEmpty)

        agent.beginTurn(enabled: true)
        let ok = await agent.clickAt(x: 0.5, y: 0.25)
        XCTAssertTrue(ok.contains("Clicked"))
        XCTAssertEqual(actions.clicks.count, 1)
    }

    func testTypeTextIsGated() async {
        let denied = await agent.typeText("hello", field: "")
        XCTAssertTrue(denied.contains("Screen help is off"))

        agent.beginTurn(enabled: true)
        let ok = await agent.typeText("hello", field: "")
        XCTAssertTrue(ok.contains("Typed"))
        XCTAssertEqual(actions.typed, ["hello"])
    }

    func testActionLimit() async {
        agent.beginTurn(enabled: true)
        for _ in 0..<ScreenAgent.maxActionsPerTurn {
            _ = await agent.clickAt(x: 0.1, y: 0.1)
        }
        let blocked = await agent.clickAt(x: 0.2, y: 0.2)
        XCTAssertTrue(blocked.contains("Action limit"))
        XCTAssertEqual(actions.clicks.count, ScreenAgent.maxActionsPerTurn)
    }

    func testResetSessionDisablesTools() async {
        agent.beginTurn(enabled: true)
        _ = await agent.look()
        agent.resetSession()
        let denied = await agent.look()
        XCTAssertTrue(denied.contains("Screen help is off"))
    }
}

@MainActor
final class AssistantViewModelScreenTests: XCTestCase {
    private var mockProvider: MockAIProvider!
    private var viewModel: AssistantViewModel!
    private var capturer: MockScreenCapturer!

    override func setUp() async throws {
        TestUserDefaults.setKeepHistory(true)
        mockProvider = MockAIProvider()
        mockProvider.streamChunks = ["Done"]
        let aiService = AIService(provider: mockProvider)
        capturer = MockScreenCapturer()
        let agent = ScreenAgent(
            capturer: capturer,
            ocr: MockOCR(),
            ax: MockAXSnapshotter(),
            actions: MockScreenActions(),
            permission: MockScreenPermission(),
            accessibilityTrusted: { true }
        )
        viewModel = AssistantViewModel(aiService: aiService, store: nil, screenAgent: agent)
    }

    override func tearDown() {
        TestUserDefaults.resetKeepHistory()
        super.tearDown()
    }

    private func waitUntilSendingFinished(timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.isSending && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func testOrdinaryPromptDoesNotCaptureScreen() async {
        viewModel.input = "Hi Pico"
        viewModel.send()
        await waitUntilSendingFinished()
        XCTAssertEqual(capturer.captureCount, 0)
        XCTAssertNil(mockProvider.lastExtraContext)
    }

    func testLookToggleCapturesAndPassesContext() async {
        viewModel.lookAtScreen = true
        viewModel.input = "Hi Pico"
        viewModel.send()
        await waitUntilSendingFinished()
        XCTAssertEqual(capturer.captureCount, 1)
        XCTAssertNotNil(mockProvider.lastExtraContext)
        XCTAssertTrue(mockProvider.lastExtraContext?.contains("Submit") == true)
        XCTAssertEqual(viewModel.messages.last?.content, "Done")
    }

    func testScreenPromptCapturesWithoutToggle() async {
        viewModel.input = "What's on my screen?"
        viewModel.send()
        await waitUntilSendingFinished()
        XCTAssertEqual(capturer.captureCount, 1)
        XCTAssertNotNil(mockProvider.lastExtraContext)
    }
}
