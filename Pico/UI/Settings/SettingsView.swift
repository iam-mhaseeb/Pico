import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @AppStorage(PreferenceKey.showPico) private var showPico = true
    @AppStorage(PreferenceKey.keepHistory) private var keepHistory = true
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(PreferenceKey.petEdgeSnapEnabled) private var petEdgeSnapEnabled = true

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
                Text("When on, Pico springs to the nearest edge after you drag. Turn off to leave Pico free wherever you drop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pet gestures") {
                LabeledContent("Pet", value: "Click")
                LabeledContent("Feed", value: "Double-click")
                LabeledContent("Shoo", value: "Right-click")
                LabeledContent("Menu", value: "Press & hold")
                Text("Gestures play short reactions without opening Ask Pico. Drag still repositions Pico.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard") {
                LabeledContent("Ask Pico", value: "⌥ Space")
                LabeledContent("Text Actions", value: "⌥ ⇧ Space")
                if coordinator.hotkeyRegistrationFailed {
                    Text("Shortcut unavailable. It may be used by another app.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("AI") {
                Picker("Provider", selection: .constant("mac_local")) {
                    Text("On-device AI").tag("mac_local")
                }
                .disabled(true)
                Text("When using on-device AI, your text stays on your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 420, height: 560)
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
}
