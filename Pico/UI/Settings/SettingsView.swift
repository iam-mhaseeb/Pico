import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @AppStorage(PreferenceKey.showPico) private var showPico = true
    @AppStorage(PreferenceKey.keepHistory) private var keepHistory = true
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(PreferenceKey.petEdgeSnapEnabled) private var petEdgeSnapEnabled = true
    @AppStorage(PreferenceKey.ghostModeEnabled) private var ghostModeEnabled = true

    @State private var launchError: String?
    @State private var confirmClear = false

    var body: some View {
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

                Toggle("Show Pico", isOn: $showPico)
                    .onChange(of: showPico) { _, newValue in
                        coordinator.setShowPico(newValue)
                    }

                Text("Pico position")
                Text("Drag Pico on the desktop to move. Position is remembered.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Snap to screen edges", isOn: $petEdgeSnapEnabled)
                Text("When on, Pico springs to a nearby edge if you drop close enough. Turn off to leave Pico free wherever you drop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Ghost Mode", isOn: $ghostModeEnabled)
                    .onChange(of: ghostModeEnabled) { _, newValue in
                        coordinator.setGhostModeEnabled(newValue)
                    }
                Text("Ghost Mode fades Pico while you focus a text field, then restores after a short idle. Pause hides Pico and disables hotkeys.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pet gestures") {
                LabeledContent("Ask Pico", value: "Click")
                LabeledContent("Pet", value: "Double-click")
                LabeledContent("Menu / Feed / Shoo", value: "Right-click")
                Text("Drag still repositions Pico. Ambient gestures pause while Ask is busy.")
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
        .frame(width: 420, height: 640)
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
