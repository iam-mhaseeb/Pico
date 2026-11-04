import XCTest
@testable import Pico

final class PermissionOpenerTests: XCTestCase {
    func testResetArgumentsTargetOnlyThisAppsAccessibilityEntry() {
        XCTAssertEqual(
            PermissionOpener.accessibilityResetArguments(bundleID: "com.iamhaseb.Pico"),
            ["reset", "Accessibility", "com.iamhaseb.Pico"]
        )
    }
}
