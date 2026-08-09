import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var role: String
    var content: String
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
    }
}

struct MessageView: View {
    let message: ChatMessage
    var onCopy: (() -> Void)?
    var onRetry: (() -> Void)?

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
                if message.role == "assistant" {
                    MarkdownText(text: message.content.isEmpty && message.isStreaming ? "…" : message.content)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                }

                if message.role == "assistant", !message.isStreaming, !message.content.isEmpty {
                    HStack(spacing: 10) {
                        Button("Copy") { onCopy?() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        if onRetry != nil {
                            Button("Retry") { onRetry?() }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: PicoTheme.controlCornerRadius, style: .continuous)
                    .fill(
                        message.role == "user"
                            ? PicoTheme.accent.opacity(0.18)
                            : Color.primary.opacity(0.05)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PicoTheme.controlCornerRadius, style: .continuous)
                            .strokeBorder(
                                message.role == "user"
                                    ? PicoTheme.accent.opacity(0.22)
                                    : Color.primary.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            )
            if message.role == "assistant" { Spacer(minLength: 40) }
        }
    }
}
