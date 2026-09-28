import SwiftUI

struct PetSpeechBubbleView: View {
    let text: String
    var placeBelow: Bool = false
    var onDismiss: (() -> Void)?

    private var bubbleFill: Color { Color(nsColor: .textBackgroundColor) }
    private var bubbleText: Color { Color(nsColor: .labelColor) }

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(bubbleText)
                .lineLimit(2)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(bubbleText.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bubbleFill.opacity(0.96))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
        )
        .overlay(alignment: placeBelow ? .top : .bottom) {
            BubbleTail(pointDown: !placeBelow)
                .fill(bubbleFill.opacity(0.96))
                .frame(width: 10, height: 6)
                .offset(y: placeBelow ? -3 : 3)
        }
        .accessibilityElement(children: onDismiss == nil ? .ignore : .contain)
        .accessibilityLabel("Pico says \(text)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct BubbleTail: Shape {
    var pointDown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointDown {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}
