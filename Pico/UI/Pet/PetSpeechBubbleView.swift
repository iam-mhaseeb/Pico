import SwiftUI

struct PetSpeechBubbleView: View {
    let text: String
    var placeBelow: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.14))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
            )
            .overlay(alignment: placeBelow ? .top : .bottom) {
                BubbleTail(pointDown: !placeBelow)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 10, height: 6)
                    .offset(y: placeBelow ? -3 : 3)
            }
            .accessibilityElement(children: .ignore)
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
