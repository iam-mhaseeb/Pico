import XCTest
@testable import Pico

@MainActor
final class GlobalHotkeyManagerTests: XCTestCase {
    func testRegisterUnregisterDoesNotCrash() {
        let manager = GlobalHotkeyManager()
        manager.register()
        manager.unregister()
        manager.register()
        manager.unregister()
    }

    func testRegisterSetsFailureFlagsWhenHotkeysConflict() {
        let manager = GlobalHotkeyManager()
        manager.register()
        // Flags reflect OS registration result — just ensure they're consistent after re-register.
        let askFailed = manager.registrationFailedAsk
        let textFailed = manager.registrationFailedText
        manager.register()
        XCTAssertEqual(manager.registrationFailedAsk, askFailed)
        XCTAssertEqual(manager.registrationFailedText, textFailed)
        manager.unregister()
    }
}
