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
            VStack(spacing: 0) {
                TextField("Search history", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, PicoTheme.panelPadding)
                    .padding(.top, 12)
                historyBody
            }
        }
        .frame(width: 360, height: 480)
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
        .alert(
            "Rename conversation",
            isPresented: Binding(
                get: { viewModel.conversationPendingRename != nil },
                set: { if !$0 { viewModel.cancelRename() } }
            )
        ) {
            TextField("Title", text: $viewModel.renameDraft)
            Button("Save") { viewModel.confirmRename() }
            Button("Cancel", role: .cancel) { viewModel.cancelRename() }
        }
    }

    private var historyBody: some View {
        Group {
                if let loadError = viewModel.loadError {
                    Text(loadError)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.displayedSections.isEmpty {
                    EmptyStateView(
                        title: viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "No conversations yet"
                            : "No matches",
                        message: viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Ask me something and I’ll keep it here for you."
                            : "Try a different word from the chat title."
                    )
                    .padding(.bottom, 12)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.displayedSections) { section in
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
                                            Button("Rename") {
                                                viewModel.beginRename(conversation)
                                            }
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
    }

