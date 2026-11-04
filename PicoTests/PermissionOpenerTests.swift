import XCTest
@testable import Pico

final class PermissionOpenerTests: XCTestCase {
    func testFallbackBundleIDMatchesTheProject() {
        XCTAssertEqual(PermissionOpener.fallbackBundleID, "com.iamhaseeb.Pico")
    }

    func testDetectsAppTranslocation() {
        XCTAssertTrue(PermissionOpener.isTranslocated(
            path: "/private/var/folders/ab/cd/T/AppTranslocation/1234-ABCD/d/Pico.app"
        ))
        XCTAssertFalse(PermissionOpener.isTranslocated(path: "/Applications/Pico.app"))
        XCTAssertFalse(PermissionOpener.isTranslocated(path: "/Users/me/Downloads/Pico.app"))
    }

    func testResetArgumentsTargetOnlyThisAppsAccessibilityEntry() {
        XCTAssertEqual(
            PermissionOpener.accessibilityResetArguments(bundleID: "com.iamhaseeb.Pico"),
            ["reset", "Accessibility", "com.iamhaseeb.Pico"]
        )
    }
}
