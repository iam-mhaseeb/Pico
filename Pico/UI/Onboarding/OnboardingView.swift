import SwiftUI

struct OnboardingView: View {
    var onFinished: () -> Void
    @State private var page = 0
    @State private var launchAtLoginPreferred = false

    private let steps: [(title: String, shortTitle: String)] = [
        ("Meet", "Meet"),
        ("Text", "Text"),
        ("Menu", "Menu"),
        ("Access", "Access"),
        ("Ready", "Ready")
    ]

    var body: some View {
        VStack(spacing: 20) {
            stepIndicator

            Group {
                switch page {
                case 0: meetPage
                case 1: textPage
                case 2: menuBarPage
                case 3: permissionsPage
                case 4: readyPage
                default: meetPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                if page > 0 {
                    Button("Back") { page -= 1 }
                }
                Spacer()
                if page < steps.count - 1 {
                    Button("Continue") { page += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Let’s go") {
                        finish()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
        .frame(width: 420, height: 460)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: PicoTheme.panelCornerRadius, style: .continuous))
    }

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let isCompleted = index < page
                let isCurrent = index == page

                VStack(spacing: 6) {
                    ZStack {
                        Capsule()
                            .fill(trackColor(isCompleted: isCompleted, isCurrent: isCurrent))
                            .frame(height: 6)
                        if isCurrent {
                            Capsule()
                                .fill(PicoTheme.accent)
                                .frame(height: 6)
                        }
                    }
                    Text(step.shortTitle)
                        .font(.caption2.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent || isCompleted ? Color.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < page ? PicoTheme.accent.opacity(0.7) : Color.primary.opacity(0.12))
                        .frame(width: 10, height: 2)
                        .offset(y: -8)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding step \(page + 1) of \(steps.count): \(steps[page].title)")
    }

    private func trackColor(isCompleted: Bool, isCurrent: Bool) -> Color {
        if isCompleted {
            return PicoTheme.accent.opacity(0.7)
        }
        if isCurrent {
            return PicoTheme.accent.opacity(0.25)
        }
        return Color.primary.opacity(0.12)
    }

    private var meetPage: some View {
        VStack(spacing: 16) {
            PetFaceView(state: .success, size: 72)
            Text("Hi, I’m Pico")
                .font(.title.weight(.semibold))
            Text("Your private, on-device writing helper.")
                .foregroundStyle(.secondary)
        }
    }

    private var textPage: some View {
        VStack(spacing: 16) {
            Text("Improve anything you write")
                .font(.title2.weight(.semibold))
            Text("Select text in any app and press")
                .foregroundStyle(.secondary)
            Text("⌥ ⇧ Space")
                .font(.largeTitle.monospaced())
            Text("Fix grammar, rewrite, change tone, or shorten — then preview the changes before inserting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var menuBarPage: some View {
        VStack(spacing: 16) {
            PetFaceView(state: .idle, size: 72)
            Text("Pico lives in your menu bar")
                .font(.title2.weight(.semibold))
            Text("Click the Pico face to open Text Actions, settings, or pause. Pico stays out of your way.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("One permission")
                .font(.title2.weight(.semibold))
            Text("Accessibility lets Pico read the text you select and replace it with the version you approve. Your text never leaves this Mac.")
                .foregroundStyle(.secondary)
            Button("Open Accessibility Settings") {
                PermissionOpener.requestAccessibilityAccessAndOpenSettings()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readyPage: some View {
        VStack(spacing: 16) {
            PetFaceView(state: .success, size: 72)
            Text("You’re ready!")
                .font(.title.weight(.semibold))
            Text("Pico will sit quietly in the menu bar until you need help.")
                .foregroundStyle(.secondary)
            Toggle("Launch Pico at login", isOn: $launchAtLoginPreferred)
                .toggleStyle(.checkbox)
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: PreferenceKey.hasCompletedOnboarding)
        UserDefaults.standard.set(launchAtLoginPreferred, forKey: PreferenceKey.launchAtLogin)
        if launchAtLoginPreferred {
            try? LaunchAtLoginManager.setEnabled(true)
        }
        onFinished()
    }
}
