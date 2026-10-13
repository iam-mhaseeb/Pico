import Carbon
import SwiftData
import XCTest
@testable import Pico

final class VersionCompareTests: XCTestCase {
    func testNewerTagWins() {
        XCTAssertTrue(VersionCompare.isNewer("1.1.0", than: "1.0.0"))
        XCTAssertTrue(VersionCompare.isNewer("v2.0", than: "1.9.9"))
        XCTAssertTrue(VersionCompare.isNewer("1.10.0", than: "1.9.0"))
        XCTAssertTrue(VersionCompare.isNewer(" 1.2 ", than: "1.1.9"))
        XCTAssertTrue(VersionCompare.isNewer("V1.0.1", than: "v1.0.0"))
        XCTAssertFalse(VersionCompare.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(VersionCompare.isNewer("1.0", than: "1.0.1"))
        XCTAssertFalse(VersionCompare.isNewer("1.2.3", than: "1.2.3.1"))
        XCTAssertFalse(VersionCompare.isNewer("abc", than: "1.0.0"))
        XCTAssertFalse(VersionCompare.isNewer("01.2", than: "1.2.0"))
    }
}

final class UpdateCheckInterpreterTests: XCTestCase {
    func testMissingReleaseNamesTheCurrentVersion() {
        let result = UpdateChecker.interpret(statusCode: 404, body: Data(), currentVersion: "1.0.0")
        XCTAssertTrue(result.message.contains("No public release"))
        XCTAssertTrue(result.message.contains("1.0.0"))
        XCTAssertNil(result.releaseURL)
    }

    func testNewerReleaseOffersThePage() {
        let body = Data(#"{"tag_name":"v1.4.0","html_url":"https://github.com/iam-mhaseeb/Pico/releases/tag/v1.4.0"}"#.utf8)
        let result = UpdateChecker.interpret(statusCode: 200, body: body, currentVersion: "1.0.0")
        XCTAssertTrue(result.message.contains("v1.4.0"))
        XCTAssertTrue(result.message.contains("available"))
        XCTAssertEqual(result.releaseURL?.absoluteString, "https://github.com/iam-mhaseeb/Pico/releases/tag/v1.4.0")
    }

    func testSameVersionIsUpToDate() {
        let body = Data(#"{"tag_name":"1.0.0","html_url":"https://github.com/iam-mhaseeb/Pico/releases/tag/1.0.0"}"#.utf8)
        let result = UpdateChecker.interpret(statusCode: 200, body: body, currentVersion: "1.0.0")
        XCTAssertTrue(result.message.contains("up to date"))
        XCTAssertNotNil(result.releaseURL)
    }

    func testBadPayloadAndServerError() {
        let bad = UpdateChecker.interpret(statusCode: 200, body: Data("nope".utf8), currentVersion: "1.0.0")
        XCTAssertTrue(bad.message.contains("Couldn’t"))
        XCTAssertNil(bad.releaseURL)
        let server = UpdateChecker.interpret(statusCode: 500, body: Data(), currentVersion: "1.0.0")
        XCTAssertTrue(server.message.contains("Couldn’t"))
    }
}

final class ScreenAllowlistTests: XCTestCase {
    func testDisabledAllowlistAllowsAnyApp() {
        let defaults = UserDefaults(suiteName: "ScreenAllowlistTests")!
        defaults.removePersistentDomain(forName: "ScreenAllowlistTests")
        XCTAssertTrue(ScreenAllowlist.allows(bundleID: nil, defaults: defaults))
        XCTAssertNil(ScreenAllowlist.blockMessage(bundleID: nil, appName: "Safari", defaults: defaults))
    }

    func testEnabledAllowlistNamesTheApp() {
        let defaults = UserDefaults(suiteName: "ScreenAllowlistTests")!
        defaults.removePersistentDomain(forName: "ScreenAllowlistTests")
        ScreenAllowlist.setEnabled(true, defaults: defaults)
        ScreenAllowlist.save([ScreenAllowlist.AppEntry(bundleID: "com.apple.Safari", name: "Safari")], defaults: defaults)
        XCTAssertTrue(ScreenAllowlist.allows(bundleID: "com.apple.Safari", defaults: defaults))
        XCTAssertFalse(ScreenAllowlist.allows(bundleID: "com.apple.mail", defaults: defaults))
        XCTAssertTrue(
            ScreenAllowlist.blockMessage(bundleID: "com.apple.mail", appName: "Mail", defaults: defaults)?
                .contains("Mail") == true
        )
        XCTAssertNil(ScreenAllowlist.blockMessage(bundleID: "com.apple.Safari", appName: "Safari", defaults: defaults))
        XCTAssertFalse(ScreenAllowlist.allows(bundleID: "", defaults: defaults))
        XCTAssertFalse(ScreenAllowlist.allows(bundleID: nil, defaults: defaults))
    }

    func testTurningTheListOffAllowsEveryAppAgain() {
        let defaults = UserDefaults(suiteName: "ScreenAllowlistTestsOff")!
        defaults.removePersistentDomain(forName: "ScreenAllowlistTestsOff")
        ScreenAllowlist.setEnabled(true, defaults: defaults)
        ScreenAllowlist.save([], defaults: defaults)
        XCTAssertFalse(ScreenAllowlist.allows(bundleID: "com.apple.Safari", defaults: defaults))
        ScreenAllowlist.setEnabled(false, defaults: defaults)
        XCTAssertTrue(ScreenAllowlist.allows(bundleID: "com.apple.Safari", defaults: defaults))
        XCTAssertNil(ScreenAllowlist.blockMessage(bundleID: "com.apple.Safari", appName: "Safari", defaults: defaults))
    }

    func testSaveReplacesTheList() {
        let defaults = UserDefaults(suiteName: "ScreenAllowlistTestsSave")!
        defaults.removePersistentDomain(forName: "ScreenAllowlistTestsSave")
        ScreenAllowlist.save([
            ScreenAllowlist.AppEntry(bundleID: "a", name: "A"),
            ScreenAllowlist.AppEntry(bundleID: "b", name: "B")
        ], defaults: defaults)
        ScreenAllowlist.save([ScreenAllowlist.AppEntry(bundleID: "c", name: "C")], defaults: defaults)
        XCTAssertEqual(ScreenAllowlist.apps(defaults: defaults).map(\.bundleID), ["c"])
    }
}

final class SavedPromptStoreTests: XCTestCase {
    func testAddDedupesAndCaps() {
        let defaults = UserDefaults(suiteName: "SavedPromptStoreTests")!
        defaults.removePersistentDomain(forName: "SavedPromptStoreTests")
        _ = SavedPromptStore.add(title: "One", text: "Hello", defaults: defaults)
        let again = SavedPromptStore.add(title: "One again", text: "Hello", defaults: defaults)
        XCTAssertEqual(again.count, 1)
        XCTAssertEqual(again.first?.title, "One again")
    }

    func testBlankTextIsIgnoredAndBlankTitleUsesPrompt() {
        let defaults = freshDefaults("SavedPromptStoreBlank")
        XCTAssertTrue(SavedPromptStore.add(title: "Nope", text: "   ", defaults: defaults).isEmpty)
        let saved = SavedPromptStore.add(title: "  ", text: "  Keep me  ", defaults: defaults)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.title, "Prompt")
        XCTAssertEqual(saved.first?.text, "Keep me")
    }

    func testNewestStaysFirstAndTheListCaps() {
        let defaults = freshDefaults("SavedPromptStoreCap")
        for index in 0..<(SavedPromptStore.maxCount + 3) {
            _ = SavedPromptStore.add(title: "P\(index)", text: "text \(index)", defaults: defaults)
        }
        let loaded = SavedPromptStore.load(defaults: defaults)
        XCTAssertEqual(loaded.count, SavedPromptStore.maxCount)
        XCTAssertEqual(loaded.first?.text, "text \(SavedPromptStore.maxCount + 2)")
        XCTAssertFalse(loaded.contains { $0.text == "text 0" })
    }

    func testRemoveDropsOnePrompt() {
        let defaults = freshDefaults("SavedPromptStoreRemove")
        let saved = SavedPromptStore.add(title: "Keep", text: "stay", defaults: defaults)
        _ = SavedPromptStore.add(title: "Drop", text: "go", defaults: defaults)
        let left = SavedPromptStore.remove(id: saved[0].id, defaults: defaults)
        XCTAssertEqual(left.map(\.text), ["go"])
        XCTAssertEqual(SavedPromptStore.remove(id: UUID(), defaults: defaults).count, 1)
    }

    private func freshDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

final class HotkeyPreferenceTests: XCTestCase {
    func testRoundTrip() {
        let defaults = UserDefaults(suiteName: "HotkeyPreferenceTests")!
        defaults.removePersistentDomain(forName: "HotkeyPreferenceTests")
        let chord = HotkeyChord(keyCode: 49, modifiers: UInt32(optionKey), label: "⌥ Space")
        HotkeyPreferences.saveAsk(chord, defaults: defaults)
        XCTAssertEqual(HotkeyPreferences.loadAsk(defaults: defaults), chord)
        XCTAssertEqual(HotkeyPreferences.loadText(defaults: defaults), .defaultText)
    }

    func testLabelIncludesModifiers() {
        let label = HotkeyChord.label(keyCode: UInt16(kVK_Space), modifiers: UInt32(optionKey | shiftKey), characters: " ")
        XCTAssertEqual(label, "⌥ ⇧ Space")
        let command = HotkeyChord.label(
            keyCode: UInt16(kVK_Return),
            modifiers: UInt32(cmdKey | controlKey),
            characters: nil
        )
        XCTAssertEqual(command, "⌃ ⌘ Return")
        XCTAssertEqual(
            HotkeyChord.label(keyCode: UInt16(kVK_LeftArrow), modifiers: 0, characters: nil),
            "Left"
        )
        XCTAssertEqual(
            HotkeyChord.label(keyCode: 40, modifiers: UInt32(optionKey), characters: "k"),
            "⌥ K"
        )
    }

    func testCarbonModifiersMatchTheEventFlags() {
        let flags = NSEvent.ModifierFlags([.command, .option, .shift, .control])
        let carbon = HotkeyChord.carbonModifiers(from: flags.rawValue)
        XCTAssertEqual(carbon & UInt32(cmdKey), UInt32(cmdKey))
        XCTAssertEqual(carbon & UInt32(optionKey), UInt32(optionKey))
        XCTAssertEqual(carbon & UInt32(shiftKey), UInt32(shiftKey))
        XCTAssertEqual(carbon & UInt32(controlKey), UInt32(controlKey))
        XCTAssertEqual(HotkeyChord.carbonModifiers(from: 0), 0)
    }

    func testCorruptStoredChordFallsBackToTheDefault() {
        let defaults = UserDefaults(suiteName: "HotkeyPreferenceCorrupt")!
        defaults.removePersistentDomain(forName: "HotkeyPreferenceCorrupt")
        defaults.set(Data("not json".utf8), forKey: PreferenceKey.askHotkey)
        XCTAssertEqual(HotkeyPreferences.loadAsk(defaults: defaults), .defaultAsk)
        HotkeyPreferences.saveText(.defaultAsk, defaults: defaults)
        XCTAssertEqual(HotkeyPreferences.loadText(defaults: defaults).label, HotkeyChord.defaultAsk.label)
    }

    func testDefaultsUseOptionSpace() {
        XCTAssertEqual(HotkeyChord.defaultAsk.label, "⌥ Space")
        XCTAssertEqual(HotkeyChord.defaultText.label, "⌥ ⇧ Space")
        XCTAssertNotEqual(HotkeyChord.defaultAsk, HotkeyChord.defaultText)
    }
}

@MainActor
final class HistoryFilterTests: XCTestCase {
    func testFilterMatchesTitle() {
        let safari = Conversation(title: "Safari notes")
        let grocery = Conversation(title: "Grocery")
        let sections = [HistorySection(id: "today", title: "Today", conversations: [safari, grocery])]
        let filtered = HistoryViewModel.filter(sections, query: "safari")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.conversations.first?.title, "Safari notes")
        XCTAssertEqual(HistoryViewModel.filter(sections, query: "  ").count, 1)
        XCTAssertEqual(HistoryViewModel.filter(sections, query: "SAFARI").first?.conversations.count, 1)
        XCTAssertTrue(HistoryViewModel.filter(sections, query: "missing").isEmpty)
    }

    func testFilterDropsSectionsWithNoMatches() {
        let today = HistorySection(id: "today", title: "Today", conversations: [Conversation(title: "Mail")])
        let older = HistorySection(id: "previous", title: "Previous", conversations: [Conversation(title: "Notes")])
        let filtered = HistoryViewModel.filter([today, older], query: "note")
        XCTAssertEqual(filtered.map(\.id), ["previous"])
    }
}

@MainActor
final class HistoryViewModelBehaviorTests: XCTestCase {
    private var viewModel: HistoryViewModel!

    override func setUp() async throws {
        TestUserDefaults.setKeepHistory(true)
        let container = try TestModelContainerFactory.inMemory()
        let store = ConversationStore(modelContext: ModelContext(container))
        viewModel = HistoryViewModel(store: store)
    }

    override func tearDown() {
        TestUserDefaults.resetKeepHistory()
        super.tearDown()
    }

    func testReloadGroupsTodayAndRenameAndDelete() throws {
        let container = try TestModelContainerFactory.inMemory()
        let context = ModelContext(container)
        let store = ConversationStore(modelContext: context)
        let recent = try store.createConversation(firstUserMessage: "Safari notes for today", providerID: "mock")
        let older = Conversation(title: "Old grocery", updatedAt: Date().addingTimeInterval(-10 * 24 * 60 * 60))
        context.insert(older)
        try context.save()
        let model = HistoryViewModel(store: store)
        model.reload()

        XCTAssertEqual(model.sections.map(\.id), ["today", "previous"])
        XCTAssertNil(model.loadError)

        model.query = "safari"
        XCTAssertEqual(model.displayedSections.count, 1)
        XCTAssertEqual(model.displayedSections.first?.conversations.first?.title, recent.title)

        model.beginRename(recent)
        XCTAssertEqual(model.renameDraft, recent.title)
        model.renameDraft = "   "
        model.confirmRename()
        XCTAssertEqual(model.sections.flatMap(\.conversations).first { $0.id == recent.id }?.title, recent.title)

        model.beginRename(recent)
        model.renameDraft = "Renamed chat"
        model.confirmRename()
        XCTAssertNil(model.conversationPendingRename)
        XCTAssertTrue(model.sections.flatMap(\.conversations).contains { $0.title == "Renamed chat" })

        model.requestDelete(recent)
        model.cancelDelete()
        XCTAssertNil(model.conversationPendingDelete)
        model.requestDelete(recent)
        model.confirmDelete()
        XCTAssertFalse(model.sections.flatMap(\.conversations).contains { $0.id == recent.id })

        model.clearAll()
        XCTAssertTrue(model.sections.isEmpty)
        _ = older
    }
}
