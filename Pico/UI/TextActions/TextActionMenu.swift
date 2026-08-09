import SwiftUI

struct TextActionMenu: View {
    @Bindable var viewModel: TextActionMenuViewModel
    var onClose: () -> Void

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
                                await viewModel.insert()
                                onClose()
                            }
                        }
                    )
                    .frame(width: 360)
                case .error(let message):
                    FriendlyErrorView(
                        message: message,
                        onRetry: {
                            if let action = viewModel.selectedAction {
                                Task { await viewModel.run(action) }
                            } else {
                                Task { await viewModel.prepare() }
                            }
                        },
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
        .onExitCommand {
            viewModel.cancel()
            onClose()
        }
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
        case .preview: return .success
        case .error, .permissionRequired, .emptySelection: return .error
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
            Text("Pico needs Accessibility access to read and replace selected text. When using local AI, your text stays on your Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Settings") {
                    PermissionOpener.requestAccessibilityAccessAndOpenSettings()
                }
                .keyboardShortcut(.defaultAction)
                Button("Close") {
                    viewModel.cancel()
                    onClose()
                }
            }
        }
        .padding(PicoTheme.panelPadding)
        .frame(width: 320)
    }
}
