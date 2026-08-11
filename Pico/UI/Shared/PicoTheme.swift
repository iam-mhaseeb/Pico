import SwiftUI

enum PicoTheme {
    static let panelCornerRadius: CGFloat = 14
    static let controlCornerRadius: CGFloat = 10
    static let petSize: CGFloat = 56
    static let petBubbleSize: CGFloat = 72
    static let panelGap: CGFloat = 12
    static let panelPadding: CGFloat = 16
    static let assistantMinWidth: CGFloat = 320
    static let assistantMinHeight: CGFloat = 360
    static let assistantDefaultWidth: CGFloat = 380
    static let assistantDefaultHeight: CGFloat = 420
    static let screenMargin: CGFloat = 20
    static let ghostOpacity: CGFloat = 0.3

    static let accent = Color(red: 0.95, green: 0.55, blue: 0.35)
    static let petBody = Color(red: 0.98, green: 0.78, blue: 0.45)
    static let petBodyShadow = Color(red: 0.85, green: 0.58, blue: 0.28)
    static let petEye = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let petCheek = Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.55)
}

enum PreferenceKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let launchAtLogin = "launchAtLogin"
    static let showPico = "showPico"
    static let keepHistory = "keepHistory"
    static let petOriginX = "petOriginX"
    static let petOriginY = "petOriginY"
    static let petDisplayID = "petDisplayID"
    static let assistantWidth = "assistantWidth"
    static let assistantHeight = "assistantHeight"
    static let aiProviderID = "aiProviderID"
    static let isPaused = "isPaused"
    /// When true, pet springs to the nearest screen edge on drag release.
    static let petEdgeSnapEnabled = "petEdgeSnapEnabled"
    /// When true, Pico fades while typing / focused in text fields.
    static let ghostModeEnabled = "ghostModeEnabled"
}
