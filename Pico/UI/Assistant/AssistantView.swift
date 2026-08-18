import SwiftUI

struct AssistantView: View {
    @Bindable var viewModel: AssistantViewModel
    var onClose: () -> Void
    var onOpenHistory: () -> Void

    var body: some View {
        PicoPanel(
            title: "Pico",
            subtitle: viewModel.conversationTitle,
            petState: viewModel.headerPetState,
            onClose: onClose,
            trailing: {
                HStack(spacing: 6) {
                    PicoIconButton(
                        systemName: "clock.arrow.circlepath",
                        help: "History",
                        action: onOpenHistory
                    )
                    PicoIconButton(
                        systemName: "square.and.pencil",
                        help: "New conversation",
                        action: { viewModel.newConversation() }
                    )
                }
            }
        ) {
            VStack(spacing: 0) {
                if let errorMessage = viewModel.errorMessage {
                    FriendlyErrorView(
                        message: errorMessage,
                        onRetry: { viewModel.retryLastFailure() },
                        onDismiss: { viewModel.errorMessage = nil }
                    )
                    .frame(maxHeight: 180)
                }

                ChatView(
                    messages: viewModel.messages,
                    onCopy: { viewModel.copy($0) },
                    onRetry: { viewModel.retry($0) }
                )
                .padding(PicoTheme.panelPadding)

                Divider().opacity(0.35)

                VStack(spacing: 8) {
                    if viewModel.screenPermissionNeeded {
                        screenPermissionBanner(
                            message: "Pico needs Screen Recording to see your screen.",
                            actionTitle: "Open Settings",
                            action: { PermissionOpener.requestScreenRecordingAccessAndOpenSettings() }
                        )
                    } else if viewModel.screenAccessibilityNeeded {
                        screenPermissionBanner(
                            message: "Pico needs Accessibility to click and type.",
                            actionTitle: "Open Settings",
                            action: { PermissionOpener.requestAccessibilityAccessAndOpenSettings() }
                        )
                    }

                    ChatInput(
                        text: $viewModel.input,
                        isSending: viewModel.isSending,
                        lookAtScreen: $viewModel.lookAtScreen,
                        screenStatus: viewModel.screenStatus,
                        onSend: { viewModel.send() }
                    )
                    HStack {
                        Text("A little AI buddy")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Look · ↵ Ask · ⇧↵ newline")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(PicoTheme.panelPadding)
            }
        }
        .onExitCommand(perform: onClose)
    }

    private func screenPermissionBanner(message: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "eye.slash")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button(actionTitle, action: action)
                .font(.caption)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: PicoTheme.controlCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
