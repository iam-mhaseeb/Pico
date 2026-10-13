import SwiftUI

enum PicoTheme {
    static let panelCornerRadius: CGFloat = 14
    static let controlCornerRadius: CGFloat = 10
    static let petSize: CGFloat = 56
    static let panelGap: CGFloat = 12
    static let panelPadding: CGFloat = 16
    static let assistantMinWidth: CGFloat = 320
    static let assistantMinHeight: CGFloat = 360
    static let assistantDefaultWidth: CGFloat = 380
    static let assistantDefaultHeight: CGFloat = 420
    static let screenMargin: CGFloat = 20

    static let accent = Color(red: 0.95, green: 0.55, blue: 0.35)
    /// Near-black pebble, with a light rim so it still shows on a dark menu bar.
    static let petBody = Color(red: 0.08, green: 0.07, blue: 0.06)
    static let petBodyShadow = Color(red: 0.08, green: 0.07, blue: 0.06)
    static let petRim = Color(red: 0.96, green: 0.93, blue: 0.88)
    static let petEyeWhite = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let petPupil = Color(red: 0.05, green: 0.04, blue: 0.04)
    static let petEye = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let petCheek = Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.55)
}

enum PreferenceKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let launchAtLogin = "launchAtLogin"
    static let keepHistory = "keepHistory"
    static let assistantWidth = "assistantWidth"
    static let assistantHeight = "assistantHeight"
    static let aiProviderID = "aiProviderID"
    static let isPaused = "isPaused"
    static let askHotkey = "askHotkey"
    static let textHotkey = "textHotkey"
    static let screenAllowlistEnabled = "screenAllowlistEnabled"
    static let screenAllowlistApps = "screenAllowlistApps"
    static let savedPrompts = "savedPrompts"
}
