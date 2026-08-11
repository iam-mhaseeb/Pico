import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    var onSelect: (Conversation) -> Void
    var onClose: () -> Void

    var body: some View {
        PicoPanel(
            title: "Pico",
            subtitle: "History",
            petState: .idle,
            onClose: onClose
        ) {
            Group {
                if let loadError = viewModel.loadError {
                    Text(loadError)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.sections.isEmpty {
                    EmptyStateView(
                        title: "No conversations yet",
                        message: "Ask me something and I’ll keep it here for you."
                    )
                    .padding(.bottom, 12)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.sections) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)

                                    ForEach(section.conversations, id: \.id) { conversation in
                                        Button {
                                            onSelect(conversation)
                                        } label: {
                                            HStack(spacing: 10) {
                                                Circle()
                                                    .fill(PicoTheme.accent.opacity(0.22))
                                                    .frame(width: 8, height: 8)
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(conversation.title)
                                                        .font(.body.weight(.medium))
                                                        .foregroundStyle(.primary)
                                                        .lineLimit(2)
                                                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer(minLength: 0)
                                                Image(systemName: "chevron.right")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding(10)
                                            .background(
                                                RoundedRectangle(cornerRadius: PicoTheme.controlCornerRadius, style: .continuous)
                                                    .fill(Color.primary.opacity(0.04))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button("Delete", role: .destructive) {
                                                viewModel.requestDelete(conversation)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(PicoTheme.panelPadding)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 320, height: 420)
        .onAppear { viewModel.reload() }
        .onExitCommand(perform: onClose)
        .confirmationDialog(
            "Delete this conversation?",
            isPresented: Binding(
                get: { viewModel.conversationPendingDelete != nil },
                set: { if !$0 { viewModel.cancelDelete() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.confirmDelete()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
        }
    }
}
