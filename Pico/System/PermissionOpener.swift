import AppKit
@preconcurrency import ApplicationServices
import Foundation

enum PermissionOpener {
    /// Used only if macOS cannot report the running app's bundle identifier.
    static let fallbackBundleID = "com.iamhaseeb.Pico"

    /// Live Accessibility trust for this process.
    static var accessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Gatekeeper runs quarantined apps from a randomized read-only location ("App Translocation")
    /// until they are moved. Permissions granted to that temporary copy do not stick.
    static func isTranslocated(path: String) -> Bool {
        path.contains("/AppTranslocation/")
    }

    static var runningFromTranslocation: Bool {
        isTranslocated(path: Bundle.main.bundlePath)
    }

    /// Starts a fresh copy of the app and quits this one. macOS can keep reporting "not trusted"
    /// to an already-running process after the user turns the permission on.
    @MainActor
    static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }

    /// Registers the running app with Accessibility (so it appears in the list), then opens Settings.
    static func requestAccessibilityAccessAndOpenSettings() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
    }

    /// Arguments for `tccutil` that clear this app's stale Accessibility entry.
    static func accessibilityResetArguments(bundleID: String) -> [String] {
        ["reset", "Accessibility", bundleID]
    }

    /// macOS ties the Accessibility permission to the exact app build. An unsigned app gets a new
    /// identity when it is updated or rebuilt, so the old "on" switch stops applying. Clearing the
    /// entry and asking again lets the user enable the current build.
    static func resetAccessibilityPermission() {
        let bundleID = Bundle.main.bundleIdentifier ?? fallbackBundleID
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = accessibilityResetArguments(bundleID: bundleID)
        try? process.run()
        process.waitUntilExit()
        requestAccessibilityAccessAndOpenSettings()
    }

    static func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.PrivacyAccessibility"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAppleIntelligenceSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Siri",
            "x-apple.systempreferences:com.apple.preference.speech"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
