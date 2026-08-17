import XCTest
import SwiftData
@testable import Pico

@MainActor
final class AssistantViewModelTests: XCTestCase {
    private var mockProvider: MockAIProvider!
    private var aiService: AIService!
    private var store: ConversationStore!
    private var viewModel: AssistantViewModel!

    override func setUp() async throws {
        TestUserDefaults.setKeepHistory(true)
        mockProvider = MockAIProvider()
        mockProvider.streamChunks = ["Hello", "Hello world"]
        aiService = AIService(provider: mockProvider)
        let container = try TestModelContainerFactory.inMemory()
        store = ConversationStore(modelContext: ModelContext(container))
        viewModel = AssistantViewModel(aiService: aiService, store: store)
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

    func testSendAppendsUserAndAssistantWithPersistedIDs() async {
        viewModel.input = "Hi Pico"
        viewModel.send()
        await waitUntilSendingFinished()

        XCTAssertFalse(viewModel.isSending)
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].role, "user")
        XCTAssertEqual(viewModel.messages[0].content, "Hi Pico")
        XCTAssertEqual(viewModel.messages[1].role, "assistant")
        XCTAssertEqual(viewModel.messages[1].content, "Hello world")
        XCTAssertFalse(viewModel.messages[1].isStreaming)

        let listed = try? store.listConversations()
        XCTAssertEqual(listed?.count, 1)
        XCTAssertEqual(listed?.first?.messages.count, 2)
        XCTAssertEqual(listed?.first?.messages.map(\.id), viewModel.messages.map(\.id))
    }

    func testRetryDoesNotDuplicateUserMessage() async {
        mockProvider.streamError = .generationFailed
        viewModel.input = "Question"
        viewModel.send()
        await waitUntilSendingFinished()

        XCTAssertNotNil(viewModel.errorMessage)
        let userCount = viewModel.messages.filter { $0.role == "user" }.count
        XCTAssertEqual(userCount, 1)

        mockProvider.streamError = nil
        mockProvider.streamChunks = ["Answer"]
        if let failedAssistant = viewModel.messages.last(where: { $0.role == "assistant" }) {
            viewModel.retry(failedAssistant)
        }
        await waitUntilSendingFinished()

        XCTAssertEqual(viewModel.messages.filter { $0.role == "user" }.count, 1)
        XCTAssertEqual(viewModel.messages.last(where: { $0.role == "assistant" })?.content, "Answer")
    }

    func testRetryLastFailureRemovesFailedAssistant() async {
        mockProvider.streamError = .generationFailed
        viewModel.input = "Question"
        viewModel.send()
        await waitUntilSendingFinished()

        mockProvider.streamError = nil
        mockProvider.streamChunks = ["Fixed"]
        viewModel.retryLastFailure()
        await waitUntilSendingFinished()

        XCTAssertEqual(viewModel.messages.filter { $0.role == "assistant" }.count, 1)
        XCTAssertEqual(viewModel.messages.last?.content, "Fixed")
    }

    func testCancelRemovesStreamingAssistantBubble() async {
        mockProvider.streamChunks = ["Part"]
        viewModel.input = "Slow"
        viewModel.send()

        for _ in 0..<5 {
            if viewModel.isSending { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        viewModel.cancel()

        for _ in 0..<100 {
            if !viewModel.isSending { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertFalse(viewModel.isSending)
        XCTAssertEqual(viewModel.messages.filter { $0.role == "assistant" }.count, 0)
        XCTAssertEqual(viewModel.messages.filter { $0.role == "user" }.count, 1)
        XCTAssertGreaterThan(mockProvider.seededHistories.count, 0)
    }

    func testNewConversationDropsSession() async {
        viewModel.input = "Hi"
        viewModel.send()
        await waitUntilSendingFinished()
        let id = viewModel.conversationID
        XCTAssertNotNil(id)

        viewModel.newConversation()
        XCTAssertNil(viewModel.conversationID)
        XCTAssertTrue(viewModel.messages.isEmpty)
        if let id {
            XCTAssertTrue(mockProvider.droppedSessionIDs.contains(id))
        }
    }

    func testLoadDifferentConversationDropsPreviousSession() throws {
        let first = try store.createConversation(firstUserMessage: "First", providerID: "mock")
        try store.appendMessage(role: "user", content: "First", to: first)
        let second = try store.createConversation(firstUserMessage: "Second", providerID: "mock")
        try store.appendMessage(role: "user", content: "Second", to: second)

        viewModel.load(conversation: first)
        let firstID = first.id
        viewModel.load(conversation: second)

        XCTAssertEqual(viewModel.conversationID, second.id)
        XCTAssertTrue(mockProvider.droppedSessionIDs.contains(firstID))
        XCTAssertEqual(mockProvider.seededHistories.last?.0, second.id)
    }

    func testCancelWhenIdleDoesNotCallProviderCancel() {
        viewModel.cancel()
        XCTAssertEqual(mockProvider.cancelCallCount, 0)
    }

    func testSendIgnoresEmptyAndWhitespace() {
        viewModel.input = "   "
        viewModel.send()
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isSending)
        XCTAssertEqual(mockProvider.cancelCallCount, 0)
    }

    func testSendWhileSendingIsIgnored() async {
        mockProvider.streamChunks = ["One"]
        viewModel.input = "First"
        viewModel.send()
        viewModel.input = "Second"
        viewModel.send()
        await waitUntilSendingFinished()
        XCTAssertEqual(viewModel.messages.filter { $0.role == "user" }.count, 1)
        XCTAssertEqual(viewModel.messages.first?.content, "First")
    }
}
