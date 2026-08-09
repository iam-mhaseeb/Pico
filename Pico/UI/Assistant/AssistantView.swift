import SwiftUI

struct AssistantView: View {
    @Bindable var viewModel: AssistantViewModel
    var onClose: () -> Void
    var onOpenHistory: () -> Void

    var body: some View {
        PicoPanel(
            title: "Pico",
            subtitle: viewModel.conversationTitle,
            petState: viewModel.isSending ? .thinking : .listening,
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
                        onRetry: {
                            viewModel.errorMessage = nil
                            if let last = viewModel.messages.last(where: { $0.role == "user" }) {
                                viewModel.input = last.content
                                viewModel.send()
                            }
                        },
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
                    ChatInput(
                        text: $viewModel.input,
                        isSending: viewModel.isSending,
                        onSend: { viewModel.send() }
                    )
                    HStack {
                        Text("A little AI buddy")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("⌘↵ Ask")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(PicoTheme.panelPadding)
            }
        }
        .onExitCommand(perform: onClose)
    }
}
