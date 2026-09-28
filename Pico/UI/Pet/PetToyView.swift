import SwiftUI

struct PetToyView: View {
    let kind: PetToyKind

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            switch kind {
            case .ball:
                context.fill(Circle().path(in: rect), with: .color(Color(red: 0.9, green: 0.3, blue: 0.28)))
                context.stroke(Circle().path(in: rect), with: .color(.white.opacity(0.7)), lineWidth: 1)
            case .yarn:
                context.fill(Circle().path(in: rect), with: .color(Color(red: 0.55, green: 0.45, blue: 0.85)))
                var strand = Path()
                strand.move(to: CGPoint(x: rect.minX + 4, y: rect.midY))
                strand.addQuadCurve(
                    to: CGPoint(x: rect.maxX - 4, y: rect.midY),
                    control: CGPoint(x: rect.midX, y: rect.minY + 2)
                )
                context.stroke(strand, with: .color(.white.opacity(0.8)), lineWidth: 1.2)
            case .laser:
                let dot = CGRect(
                    x: rect.midX - 4,
                    y: rect.midY - 4,
                    width: 8,
                    height: 8
                )
                context.fill(Circle().path(in: dot), with: .color(Color.red))
                context.fill(
                    Circle().path(in: dot.insetBy(dx: -3, dy: -3)),
                    with: .color(Color.red.opacity(0.25))
                )
            }
        }
        .frame(width: PetToyDrop.toySize, height: PetToyDrop.toySize)
        .accessibilityLabel(kind.title)
    }
}
