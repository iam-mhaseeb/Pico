import SwiftUI

struct ChatInput: View {
    @Binding var text: String
    var isSending: Bool
    @Binding var lookAtScreen: Bool
    var screenStatus: String?
    var onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let screenStatus, !screenStatus.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: lookAtScreen ? "eye.fill" : "eye")
                    Text(screenStatus)
                        .lineLimit(2)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .font(.body)
                .focused($isFocused)
                .frame(minHeight: 64, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: PicoTheme.controlCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(lookAtScreen ? "Ask Pico to look or click…" : "Ask Pico anything…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .onKeyPress(keys: [.return]) { press in
                    if press.modifiers.contains(.shift) {
                        return .ignored
                    }
                    onSend()
                    return .handled
                }

            HStack {
                Button {
                    lookAtScreen.toggle()
                } label: {
                    Label(
                        lookAtScreen ? "Looking" : "Look",
                        systemImage: lookAtScreen ? "eye.fill" : "eye"
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(lookAtScreen ? PicoTheme.accent : Color.secondary)
                .help("Look at the screen and take actions when you ask")
                .accessibilityLabel("Look at screen")
                .accessibilityValue(lookAtScreen ? "On" : "Off")

                Spacer()
                Button(action: onSend) {
                    Label("Ask", systemImage: "paperplane.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            isFocused = true
        }
    }

    func focus() {
        isFocused = true
    }
}
