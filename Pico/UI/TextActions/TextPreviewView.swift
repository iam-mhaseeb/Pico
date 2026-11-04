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
            group(title: "Original") {
                Text(original)
            }
            group(title: "Suggested (changes highlighted)") {
                Text(highlightedSuggestion)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Insert ✓", action: onInsert)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(PicoTheme.panelPadding)
    }

    private var highlightedSuggestion: AttributedString {
        let diff = TextDiff.compare(original: original, suggested: suggested)
        var result = AttributedString()
        for (index, token) in diff.tokens.enumerated() {
            var piece = AttributedString(token)
            if diff.inserted.contains(index) {
                piece.backgroundColor = PicoTheme.accent.opacity(0.3)
            }
            result += piece
        }
        return result
    }

    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                content()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 140)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: PicoTheme.controlCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
    }
}
