import SwiftUI

enum PicoTheme {
    static let panelCornerRadius: CGFloat = 14
    static let controlCornerRadius: CGFloat = 10
    static let petSize: CGFloat = 56
    static let panelPadding: CGFloat = 16

    static let accent = Color(red: 0.95, green: 0.55, blue: 0.35)

    // Pico is a pencil: yellow barrel, pink eraser, silver ferrule, wooden tip, graphite point.
    static let petBody = Color(red: 0.99, green: 0.80, blue: 0.25)
    static let petBodyShadow = Color(red: 0.80, green: 0.55, blue: 0.12)
    static let petEye = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let petCheek = Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.55)
    static let pencilEraser = Color(red: 0.97, green: 0.60, blue: 0.66)
    static let pencilFerrule = Color(red: 0.74, green: 0.77, blue: 0.82)
    static let pencilWood = Color(red: 0.94, green: 0.80, blue: 0.62)
    static let pencilGraphite = Color(red: 0.25, green: 0.26, blue: 0.30)
}

enum PreferenceKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let launchAtLogin = "launchAtLogin"
    static let isPaused = "isPaused"
}
