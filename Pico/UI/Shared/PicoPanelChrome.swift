import SwiftUI

/// Shared visual shell for Ask, History, and Text Actions so they feel like one Pico surface.
struct PicoPanel<Trailing: View, Content: View>: View {
    let title: String
    var subtitle: String?
    var petState: PetState
    var onClose: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        petState: PetState = .listening,
        onClose: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.petState = petState
        self.onClose = onClose
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content()
        }
        .background {
            RoundedRectangle(cornerRadius: PicoTheme.panelCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: PicoTheme.panelCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    PicoTheme.accent.opacity(0.10),
                                    PicoTheme.petBody.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: PicoTheme.panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PicoTheme.panelCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            PicoTheme.accent.opacity(0.40),
                            Color.primary.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                PetFaceView(state: petState, size: 30)
                    .background(
                        Circle()
                            .fill(PicoTheme.petBody.opacity(0.22))
                            .padding(-4)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                trailing()
                if let onClose {
                    PicoIconButton(systemName: "xmark", help: "Close", action: onClose)
                }
            }
            .padding(.horizontal, PicoTheme.panelPadding)
            .padding(.vertical, 12)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            PicoTheme.accent.opacity(0.55),
                            PicoTheme.petBody.opacity(0.35),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.5)
        }
    }
}

struct PicoIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
