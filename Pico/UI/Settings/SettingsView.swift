import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @AppStorage(PreferenceKey.keepHistory) private var keepHistory = true
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin = false

    @State private var launchError: String?
    @State private var confirmClear = false
    @State private var askChord = HotkeyPreferences.loadAsk()
    @State private var textChord = HotkeyPreferences.loadText()
    @State private var allowlistOn = ScreenAllowlist.isEnabled()
    @State private var allowedApps = ScreenAllowlist.apps()
    @State private var updateMessage: String?
    @State private var updateURL: URL?
    @State private var checkingUpdate = false

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

                Text("Click the Pico face to ask. Right-click it for the menu. Pause turns off shortcuts and lets the face rest.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(checkingUpdate ? "Checking…" : "Check for updates") {
                    checkingUpdate = true
                    Task {
                        let result = await UpdateChecker.check()
                        updateMessage = result.message
                        updateURL = result.releaseURL
                        checkingUpdate = false
                    }
                }
                .disabled(checkingUpdate)
                if let updateMessage {
                    Text(updateMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let updateURL {
                        Link("Open the release", destination: updateURL)
                            .font(.caption)
                    }
                }
                Text("The check asks GitHub which release is newest. It does not send your chats or screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard") {
                ShortcutRecorder(title: "Ask Pico", chord: $askChord) { chord in
                    HotkeyPreferences.saveAsk(chord)
                    coordinator.hotkeysDidChange()
                }
                ShortcutRecorder(title: "Text Actions", chord: $textChord) { chord in
                    HotkeyPreferences.saveText(chord)
                    coordinator.hotkeysDidChange()
                }
                Text("Use Option, Control, or Command with a key. Esc cancels recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if coordinator.hotkeyRegistrationFailed {
                    Text(hotkeyFailureMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Screen control") {
                Text("Before Pico clicks, types, or presses a key, it asks you to allow that step.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Only control chosen apps", isOn: $allowlistOn)
                    .onChange(of: allowlistOn) { _, newValue in
                        ScreenAllowlist.setEnabled(newValue)
                    }
                if allowlistOn {
                    if allowedApps.isEmpty {
                        Text("No apps chosen yet. Pico will refuse clicks and typing until you add one.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(allowedApps) { app in
                        HStack {
                            Text(app.name)
                            Spacer()
                            Button("Remove") {
                                allowedApps.removeAll { $0.bundleID == app.bundleID }
                                ScreenAllowlist.save(allowedApps)
                            }
                        }
                    }
                    Menu("Add running app") {
                        ForEach(ScreenAllowlist.runningApps()) { app in
                            Button(app.name) {
                                guard !allowedApps.contains(where: { $0.bundleID == app.bundleID }) else { return }
                                allowedApps.append(app)
                                allowedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                                ScreenAllowlist.save(allowedApps)
                            }
                        }
                    }
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
        .frame(width: 480, height: 680)
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
