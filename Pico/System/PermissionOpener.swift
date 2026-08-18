import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

enum PermissionOpener {
    /// Registers the running app with Accessibility (so it appears in the list), then opens Settings.
    static func requestAccessibilityAccessAndOpenSettings() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
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

    static func requestScreenRecordingAccessAndOpenSettings() {
        _ = CGRequestScreenCaptureAccess()
        openScreenRecordingSettings()
    }

    static func openScreenRecordingSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.PrivacyScreenCapture"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
        openAccessibilitySettings()
    }
}
