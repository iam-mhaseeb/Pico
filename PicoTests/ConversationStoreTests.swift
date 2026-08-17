import XCTest
import SwiftData
@testable import Pico

@MainActor
final class ConversationStoreTests: XCTestCase {
    override func tearDown() {
        TestUserDefaults.resetKeepHistory()
        super.tearDown()
    }

    func testKeepHistoryOnPersistsConversation() throws {
        TestUserDefaults.setKeepHistory(true)
        let (container, url) = try TestModelContainerFactory.onDisk()
        defer { TestModelContainerFactory.removeStore(at: url) }

        let context = ModelContext(container)
        let store = ConversationStore(modelContext: context)
        let conversation = try store.createConversation(
            firstUserMessage: "Hello persistence",
            providerID: "mock"
        )
        try store.appendMessage(role: "user", content: "Hello persistence", to: conversation)

        let reopened = try ModelContainer(
            for: Schema([Conversation.self, Message.self]),
            configurations: ModelConfiguration(url: url)
        )
        let reopenedStore = ConversationStore(modelContext: ModelContext(reopened))
        let listed = try reopenedStore.listConversations()
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.messages.count, 1)
    }

    func testKeepHistoryOffExcludesFromList() throws {
        TestUserDefaults.setKeepHistory(false)
        let container = try TestModelContainerFactory.inMemory()
        let context = ModelContext(container)
        let store = ConversationStore(modelContext: context)

        let conversation = try store.createConversation(
            firstUserMessage: "Ephemeral chat",
            providerID: "mock"
        )
        try store.appendMessage(role: "user", content: "Ephemeral chat", to: conversation)

        let listed = try store.listConversations()
        XCTAssertTrue(listed.isEmpty)

        let all = try context.fetch(FetchDescriptor<Conversation>())
        XCTAssertEqual(all.count, 1, "Ephemeral conversation remains in context but not in list")
    }

    func testKeepHistoryOffDoesNotPersistToDisk() throws {
        TestUserDefaults.setKeepHistory(false)
        let (container, url) = try TestModelContainerFactory.onDisk()
        defer { TestModelContainerFactory.removeStore(at: url) }

        let store = ConversationStore(modelContext: ModelContext(container))
        let conversation = try store.createConversation(
            firstUserMessage: "Should not survive relaunch",
            providerID: "mock"
        )
        try store.appendMessage(role: "user", content: "Should not survive relaunch", to: conversation)

        let reopened = try ModelContainer(
            for: Schema([Conversation.self, Message.self]),
            configurations: ModelConfiguration(url: url)
        )
        let listed = try ConversationStore(modelContext: ModelContext(reopened)).listConversations()
        XCTAssertTrue(listed.isEmpty)
    }

    func testClearAllRemovesPersistedConversations() throws {
        TestUserDefaults.setKeepHistory(true)
        let container = try TestModelContainerFactory.inMemory()
        let store = ConversationStore(modelContext: ModelContext(container))

        _ = try store.createConversation(firstUserMessage: "One", providerID: "mock")
        _ = try store.createConversation(firstUserMessage: "Two", providerID: "mock")
        XCTAssertEqual(try store.listConversations().count, 2)

        try store.clearAll()
        XCTAssertTrue(try store.listConversations().isEmpty)
    }

    func testDeleteMessageUpdatesConversation() throws {
        TestUserDefaults.setKeepHistory(true)
        let container = try TestModelContainerFactory.inMemory()
        let store = ConversationStore(modelContext: ModelContext(container))
        let conversation = try store.createConversation(firstUserMessage: "Title", providerID: "mock")
        let message = try store.appendMessage(role: "assistant", content: "oops", to: conversation)

        try store.deleteMessage(message)
        XCTAssertEqual(conversation.messages.count, 0)
    }

    func testAutosaveIsDisabled() throws {
        let container = try TestModelContainerFactory.inMemory()
        let context = ModelContext(container)
        let store = ConversationStore(modelContext: context)
        XCTAssertFalse(context.autosaveEnabled)
        _ = store
    }

    func testDeleteRemovesConversationFromList() throws {
        TestUserDefaults.setKeepHistory(true)
        let container = try TestModelContainerFactory.inMemory()
        let store = ConversationStore(modelContext: ModelContext(container))
        let conversation = try store.createConversation(firstUserMessage: "Bye", providerID: "mock")
        try store.delete(conversation)
        XCTAssertTrue(try store.listConversations().isEmpty)
    }

    func testSetTitlePersistsInMemory() throws {
        TestUserDefaults.setKeepHistory(true)
        let container = try TestModelContainerFactory.inMemory()
        let store = ConversationStore(modelContext: ModelContext(container))
        let conversation = try store.createConversation(firstUserMessage: "Original title here", providerID: "mock")
        try store.setTitle("Renamed", for: conversation)
        XCTAssertEqual(conversation.title, "Renamed")
        XCTAssertEqual(try store.listConversations().first?.title, "Renamed")
    }
}
