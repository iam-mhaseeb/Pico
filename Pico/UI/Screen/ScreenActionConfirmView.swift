import SwiftUI

struct ScreenActionConfirmView: View {
    let summary: String
    var onAllow: () -> Void
    var onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PetFaceView(state: .curious, size: 36, pauseAnimation: true)
                Text("Allow this?")
                    .font(.headline)
            }
            Text(summary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Text("Pico will do this in the app you were using. It still skips password fields.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Don’t allow", action: onDeny)
                    .keyboardShortcut(.cancelAction)
                Button("Allow", action: onAllow)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
