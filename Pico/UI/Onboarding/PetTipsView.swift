import SwiftUI

struct PetTipsView: View {
    var onFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pet tips")
                .font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 10) {
                tip("1", "Click to pet. Double-click to feed.")
                tip("2", "Right-click to shoo. Drag to move Pico.")
                tip("3", "Press and hold Pico to open Ask Pico.")
                tip("4", "Ghost Mode fades Pico while you type. Pause hides Pico.")
            }
            Text("The same actions are in the menu bar and Pico’s control-click menu.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Got it") { onFinished() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420, height: 280)
        .background(.regularMaterial)
    }

    private func tip(_ index: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(index)
                .font(.caption.weight(.bold))
                .foregroundStyle(PicoTheme.accent)
                .frame(width: 16)
            Text(text)
        }
        .accessibilityElement(children: .combine)
    }
}
