import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin = false

    @State private var launchError: String?

    var body: some View {
        ScrollView {
        Form {
            Section("General") {
                Toggle("Launch Pico at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try LaunchAtLoginManager.setEnabled(newValue)
                            launchError = LaunchAtLoginManager.requiresApproval
                                ? "Approval required in System Settings → Login Items."
                                : nil
                        } catch {
                            launchError = error.localizedDescription
                            launchAtLogin = LaunchAtLoginManager.isEnabled
                        }
                    }
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Pico stays in the menu bar. Pause turns off the shortcut and lets the face rest.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard") {
                LabeledContent("Text Actions", value: "⌥ ⇧ Space")
                if coordinator.hotkeyRegistrationFailed {
                    Text("The shortcut (⌥ ⇧ Space) is unavailable — another app may be using it.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Privacy") {
                Text("Your text is processed by Apple’s on-device model and never leaves your Mac. Pico needs Accessibility access to read and replace the text you select.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Accessibility settings…") {
                    PermissionOpener.requestAccessibilityAccessAndOpenSettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        }
        .frame(width: 460, height: 400)
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.isEnabled
            if LaunchAtLoginManager.requiresApproval {
                launchError = "Approval required in System Settings → Login Items."
            }
        }
    }
}
