import SwiftUI

struct ChatView: View {
    let messages: [ChatMessage]
    var onCopy: (ChatMessage) -> Void
    var onRetry: (ChatMessage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        VStack(spacing: 10) {
                            PetFaceView(state: .listening, size: 44)
                            Text("What can I help with?")
                                .font(.title3.weight(.semibold))
                            Text("Ask Pico anything from anywhere on your Mac. Turn on Look, or ask me to click what’s on screen.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(messages) { message in
                            MessageView(
                                message: message,
                                onCopy: { onCopy(message) },
                                onRetry: message.role == "assistant" ? { onRetry(message) } : nil
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: messages.last?.content) { _, _ in
                if let lastID = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }
}
