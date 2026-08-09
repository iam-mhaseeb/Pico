import SwiftUI

struct TextPreviewView: View {
    let actionTitle: String
    let original: String
    let suggested: String
    var onCancel: () -> Void
    var onInsert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(actionTitle)
                .font(.headline)
            group(title: "Original", text: original)
            group(title: "Suggested", text: suggested)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Insert ✓", action: onInsert)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(PicoTheme.panelPadding)
    }

    private func group(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: PicoTheme.controlCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
    }
}
