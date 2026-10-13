import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @AppStorage(PreferenceKey.keepHistory) private var keepHistory = true
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin = false

    @State private var launchError: String?
    @State private var confirmClear = false

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

                Text("Pico stays in the menu bar. Pause turns off shortcuts and lets the face rest.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard") {
                LabeledContent("Ask Pico", value: "⌥ Space")
                LabeledContent("Text Actions", value: "⌥ ⇧ Space")
                if coordinator.hotkeyRegistrationFailed {
                    Text(hotkeyFailureMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("AI") {
                Picker("Provider", selection: .constant("mac_local")) {
                    Text("On-device AI").tag("mac_local")
                }
                .disabled(true)
                Text("When using on-device AI, your text and screen contents stay on your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Screen help") {
                Text("Ask Pico to look at your screen or click something, or turn on Look in the Ask panel. Pico captures the display on-device and never uploads it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Screen Recording settings…") {
                    PermissionOpener.requestScreenRecordingAccessAndOpenSettings()
                }
                Button("Accessibility settings…") {
                    PermissionOpener.requestAccessibilityAccessAndOpenSettings()
                }
            }

            Section("History") {
                Toggle("Keep history", isOn: $keepHistory)
                Button("Clear history…", role: .destructive) {
                    confirmClear = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        }
        .frame(width: 460, height: 520)
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.isEnabled
            if LaunchAtLoginManager.requiresApproval {
                launchError = "Approval required in System Settings → Login Items."
            }
        }
        .confirmationDialog(
            "Delete all conversations?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Delete all conversations", role: .destructive) {
                coordinator.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var hotkeyFailureMessage: String {
        let askFailed = coordinator.hotkeyAskFailed
        let textFailed = coordinator.hotkeyTextFailed
        switch (askFailed, textFailed) {
        case (true, true):
            return "Ask (⌥ Space) and Text Actions (⌥ ⇧ Space) are unavailable — another app may be using them."
        case (true, false):
            return "Ask shortcut (⌥ Space) is unavailable — another app may be using it."
        case (false, true):
            return "Text Actions shortcut (⌥ ⇧ Space) is unavailable — another app may be using it."
        default:
            return "Shortcut unavailable. It may be used by another app."
        }
    }
}
