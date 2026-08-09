import SwiftUI

@main
struct PicoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            if let coordinator = appDelegate.coordinator {
                SettingsView(coordinator: coordinator)
            } else {
                ProgressView("Starting Pico…")
                    .frame(width: 420, height: 200)
            }
        }
        .defaultSize(width: 420, height: 480)
    }
}
