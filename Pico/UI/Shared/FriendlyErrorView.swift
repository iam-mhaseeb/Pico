import SwiftUI

struct FriendlyErrorView: View {
    let message: String
    var retryTitle: String = "Try Again"
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            PetFaceView(state: .error, size: 48)
            Text("Hmm, I couldn’t do that.")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                if let onDismiss {
                    Button("Close", action: onDismiss)
                }
                if let onRetry {
                    Button(retryTitle, action: onRetry)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding()
        .frame(maxWidth: 320)
    }
}
