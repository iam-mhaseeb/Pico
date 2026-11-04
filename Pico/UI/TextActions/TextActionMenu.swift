import SwiftUI

struct TextActionMenu: View {
    @Bindable var viewModel: TextActionMenuViewModel
    var onClose: () -> Void
    /// Called after the phase changes so the host can fit the window to the new content.
    var onPhaseChange: () -> Void = {}

    /// Rough panel size per phase, used for first placement before the window fits its content.
    static func panelSize(for phase: TextActionMenuViewModel.Phase) -> CGSize {
        switch phase {
        case .chooseAction: return CGSize(width: 320, height: 340)
        case .processing: return CGSize(width: 320, height: 220)
        case .preview: return CGSize(width: 400, height: 500)
        case .permissionRequired: return CGSize(width: 360, height: 260)
        case .emptySelection, .error: return CGSize(width: 340, height: 280)
        }
    }

    var body: some View {
        PicoPanel(
            title: "Pico",
            subtitle: subtitle,
            petState: petStateForPhase,
            onClose: {
                viewModel.cancel()
                onClose()
            }
        ) {
            Group {
                switch viewModel.phase {
                case .permissionRequired:
                    permissionView
                case .emptySelection:
                    EmptyStateView(
                        title: "Select some text first",
                        message: "Highlight text in any app, then press ⌥ ⇧ Space."
                    )
                    .frame(width: 280, height: 200)
                case .chooseAction:
                    actionList
                case .processing:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Pico is thinking…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 260, height: 140)
                case .preview:
                    TextPreviewView(
                        actionTitle: viewModel.selectedAction?.title ?? "Result",
                        original: viewModel.originalText,
                        suggested: viewModel.suggestedText,
                        onCancel: {
                            viewModel.cancel()
                            onClose()
                        },
                        onInsert: {
                            Task {
                                let succeeded = await viewModel.insert()
                                if succeeded {
                                    onClose()
                                }
                            }
                        }
                    )
                    .frame(width: 360)
                case .error(let message):
                    FriendlyErrorView(
                        message: message,
                        onRetry: retryAction,
                        onDismiss: {
                            viewModel.cancel()
                            onClose()
                        }
                    )
                    .frame(width: 300)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onChange(of: viewModel.phase) { _, _ in
            onPhaseChange()
        }
        .onExitCommand {
            viewModel.cancel()
            onClose()
        }
    }

    private var retryAction: (() -> Void)? {
        guard let action = viewModel.selectedAction else { return nil }
        return { Task { await viewModel.run(action) } }
    }

    private var subtitle: String {
        switch viewModel.phase {
        case .chooseAction: return "What should Pico do?"
        case .processing: return "Working on your text"
        case .preview: return viewModel.selectedAction?.title ?? "Preview"
        case .permissionRequired: return "Accessibility needed"
        case .emptySelection: return "No text selected"
        case .error: return "Something went wrong"
        }
    }

    private var petStateForPhase: PetState {
        switch viewModel.phase {
        case .processing: return .thinking
        case .preview: return .curious
        case .error: return .error
        case .permissionRequired, .emptySelection: return .curious
        case .chooseAction: return .listening
        }
    }

    private var actionList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(TextAction.allCases) { action in
                Button {
                    Task { await viewModel.run(action) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.symbolName)
                            .foregroundStyle(PicoTheme.accent)
                            .frame(width: 18)
                        Text(action.title)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: PicoTheme.controlCornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PicoTheme.panelPadding)
        .frame(width: 280)
    }

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pico needs Accessibility access to read and replace the text you select. Your text stays on your Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Already switched on in System Settings? macOS ties the permission to the exact app build, so after an update it can go stale. Choose Reset, then enable Pico again.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open Settings") {
                    PermissionOpener.requestAccessibilityAccessAndOpenSettings()
                }
                .keyboardShortcut(.defaultAction)
                Button("Reset & Re-enable") {
                    PermissionOpener.resetAccessibilityPermission()
                }
                Button("Close") {
                    viewModel.cancel()
                    onClose()
                }
            }
        }
        .padding(PicoTheme.panelPadding)
        .frame(width: 360)
    }
}
