import SwiftUI

enum PicoTheme {
    static let panelCornerRadius: CGFloat = 14
    static let controlCornerRadius: CGFloat = 10
    static let petSize: CGFloat = 56
    static let panelPadding: CGFloat = 16

    static let accent = Color(red: 0.95, green: 0.55, blue: 0.35)
    static let petBody = Color(red: 0.98, green: 0.78, blue: 0.45)
    static let petBodyShadow = Color(red: 0.85, green: 0.58, blue: 0.28)
    static let petEye = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let petCheek = Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.55)
}

enum PreferenceKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let launchAtLogin = "launchAtLogin"
    static let isPaused = "isPaused"
}
