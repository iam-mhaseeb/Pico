import SwiftUI

struct PetFaceView: View {
    let state: PetState
    var size: CGFloat = PicoTheme.petSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 : 1.0 / 20.0)) { context in
            let metrics = PetAnimationMetrics.metrics(
                for: state,
                date: context.date,
                reduceMotion: reduceMotion
            )
            Canvas { context, canvasSize in
                let rect = CGRect(origin: .zero, size: canvasSize)
                drawPet(context: context, in: rect, metrics: metrics, state: state)
            }
            .frame(width: size, height: size)
            .scaleEffect(metrics.breatheScale)
            .offset(y: metrics.bounceOffset)
            .rotationEffect(metrics.earTilt / 8)
        }
        .accessibilityLabel("Pico")
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        switch state {
        case .idle: return "Idle"
        case .listening: return "Listening"
        case .thinking: return "Thinking"
        case .success: return "Happy"
        case .error: return "Something went wrong"
        }
    }

    private func drawPet(
        context: GraphicsContext,
        in rect: CGRect,
        metrics: PetAnimationMetrics,
        state: PetState
    ) {
        let body = Ellipse().path(in: rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.14))
        context.fill(body, with: .color(PicoTheme.petBody))
        context.stroke(body, with: .color(PicoTheme.petBodyShadow.opacity(0.45)), lineWidth: 1.5)

        let leftEar = earPath(in: rect, left: true)
        let rightEar = earPath(in: rect, left: false)
        context.fill(leftEar, with: .color(PicoTheme.petBody))
        context.fill(rightEar, with: .color(PicoTheme.petBody))

        let eyeY = rect.midY - rect.height * 0.05
        let eyeSize = CGSize(width: rect.width * 0.11, height: rect.height * 0.13 * metrics.blinkOpacity)
        let leftEye = Ellipse().path(
            in: CGRect(
                x: rect.midX - rect.width * 0.18,
                y: eyeY - eyeSize.height / 2,
                width: eyeSize.width,
                height: max(eyeSize.height, 1)
            )
        )
        let rightEye = Ellipse().path(
            in: CGRect(
                x: rect.midX + rect.width * 0.07,
                y: eyeY - eyeSize.height / 2,
                width: eyeSize.width,
                height: max(eyeSize.height, 1)
            )
        )
        context.fill(leftEye, with: .color(PicoTheme.petEye))
        context.fill(rightEye, with: .color(PicoTheme.petEye))

        let cheekSize = CGSize(width: rect.width * 0.12, height: rect.height * 0.08)
        context.fill(
            Ellipse().path(in: CGRect(x: rect.midX - rect.width * 0.28, y: rect.midY + rect.height * 0.05, width: cheekSize.width, height: cheekSize.height)),
            with: .color(PicoTheme.petCheek)
        )
        context.fill(
            Ellipse().path(in: CGRect(x: rect.midX + rect.width * 0.16, y: rect.midY + rect.height * 0.05, width: cheekSize.width, height: cheekSize.height)),
            with: .color(PicoTheme.petCheek)
        )

        var mouth = Path()
        let mouthY = rect.midY + rect.height * 0.16
        switch state {
        case .error:
            mouth.addArc(
                center: CGPoint(x: rect.midX, y: mouthY + 4),
                radius: rect.width * 0.08,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: true
            )
        case .success, .listening:
            mouth.addArc(
                center: CGPoint(x: rect.midX, y: mouthY - 2),
                radius: rect.width * 0.09,
                startAngle: .degrees(20),
                endAngle: .degrees(160),
                clockwise: false
            )
        case .thinking:
            mouth.addEllipse(in: CGRect(x: rect.midX - 2, y: mouthY, width: 4, height: 4))
        case .idle:
            mouth.move(to: CGPoint(x: rect.midX - 6, y: mouthY))
            mouth.addQuadCurve(
                to: CGPoint(x: rect.midX + 6, y: mouthY),
                control: CGPoint(x: rect.midX, y: mouthY + 4)
            )
        }
        context.stroke(mouth, with: .color(PicoTheme.petEye), lineWidth: 1.8)

        if state == .thinking {
            let dotY = rect.minY + rect.height * 0.08
            for index in 0..<3 {
                let x = rect.midX + CGFloat(index - 1) * 7
                context.fill(
                    Circle().path(in: CGRect(x: x, y: dotY, width: 3.5, height: 3.5)),
                    with: .color(PicoTheme.accent.opacity(0.8))
                )
            }
        }
    }

    private func earPath(in rect: CGRect, left: Bool) -> Path {
        var path = Path()
        let tipX = left ? rect.minX + rect.width * 0.22 : rect.maxX - rect.width * 0.22
        let baseInnerX = left ? rect.midX - rect.width * 0.08 : rect.midX + rect.width * 0.08
        let baseOuterX = left ? rect.minX + rect.width * 0.32 : rect.maxX - rect.width * 0.32
        path.move(to: CGPoint(x: tipX, y: rect.minY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: baseOuterX, y: rect.minY + rect.height * 0.28))
        path.addLine(to: CGPoint(x: baseInnerX, y: rect.minY + rect.height * 0.28))
        path.closeSubpath()
        return path
    }
}

struct PetView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        PetFaceView(state: coordinator.petState, size: PicoTheme.petSize)
            .frame(width: PicoTheme.petSize, height: PicoTheme.petSize)
            .background(Color.clear)
            // Drag, click, and context menu are handled by DraggablePetContainer.
    }
}
