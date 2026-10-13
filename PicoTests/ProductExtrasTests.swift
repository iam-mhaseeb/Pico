import Carbon
import XCTest
@testable import Pico

final class VersionCompareTests: XCTestCase {
    func testNewerTagWins() {
        XCTAssertTrue(VersionCompare.isNewer("1.1.0", than: "1.0.0"))
        XCTAssertTrue(VersionCompare.isNewer("v2.0", than: "1.9.9"))
        XCTAssertFalse(VersionCompare.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(VersionCompare.isNewer("1.0", than: "1.0.1"))
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
    }
}
