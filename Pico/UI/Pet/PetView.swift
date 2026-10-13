import SwiftUI

/// Pico’s face, drawn like the Grok Bot mark: a pebble and two capsule eyes.
/// Expression lives in the eyes. There is no smile, so it still reads at menu-bar size.
struct PetFaceView: View {
    let state: PetState
    var size: CGFloat = PicoTheme.petSize
    var animationInterval: TimeInterval = 1.0 / 20.0
    var pauseAnimation: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if pauseAnimation || reduceMotion {
                face(date: Date(timeIntervalSinceReferenceDate: 0), reduceMotion: true)
            } else {
                TimelineView(.animation(minimumInterval: max(animationInterval, 1.0 / 30.0))) { context in
                    face(date: context.date, reduceMotion: false)
                }
            }
        }
        .accessibilityLabel("Pico")
        .accessibilityHint(state.accessibilityDescription)
        .accessibilityValue(state.accessibilityDescription)
    }

    private func face(date: Date, reduceMotion: Bool) -> some View {
        let metrics = PetAnimationMetrics.metrics(
            for: state,
            date: date,
            reduceMotion: reduceMotion
        )
        return Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            drawPet(context: context, in: rect, metrics: metrics, state: state)
        }
        .frame(width: size, height: size)
        .scaleEffect(
            x: metrics.breatheScale * metrics.squashX,
            y: metrics.breatheScale * metrics.squashY
        )
        .offset(y: metrics.bounceOffset * (size / PicoTheme.petSize))
        .rotationEffect(metrics.earTilt / 10)
    }

    private func drawPet(
        context: GraphicsContext,
        in rect: CGRect,
        metrics: PetAnimationMetrics,
        state: PetState
    ) {
        let pebble = pebblePath(in: rect)
        context.fill(pebble, with: .color(PicoTheme.petBody))
        context.stroke(
            pebble,
            with: .color(PicoTheme.petRim),
            lineWidth: max(1, rect.width * 0.055)
        )

        var highlight = Path()
        highlight.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.22,
            y: rect.minY + rect.height * 0.16,
            width: rect.width * 0.28,
            height: rect.height * 0.16
        ))
        context.fill(highlight, with: .color(PicoTheme.accent.opacity(0.55)))

        let look = glance(for: state)
        let openness = eyeOpenness(for: state) * max(metrics.blinkOpacity, state == .sleeping ? 0.08 : 0.16)
        drawEye(
            context: context,
            in: rect,
            anchor: CGPoint(x: 0.36, y: 0.43),
            tilt: state == .error || state == .sad ? -28 : -16,
            openness: openness,
            glance: look,
            lift: state == .curious ? -0.04 : 0
        )
        drawEye(
            context: context,
            in: rect,
            anchor: CGPoint(x: 0.64, y: 0.40),
            tilt: state == .curious ? -6 : -18,
            openness: openness * (state == .sad ? 0.85 : 1),
            glance: look,
            lift: 0
        )
    }

    private func glance(for state: PetState) -> CGSize {
        switch state {
        case .idle:
            return CGSize(width: 0.22, height: -0.28)
        case .listening, .love:
            return CGSize(width: 0.05, height: -0.08)
        case .thinking, .working:
            return CGSize(width: 0.18, height: -0.55)
        case .success, .celebrating:
            return CGSize(width: 0.08, height: -0.34)
        case .error, .sad:
            return CGSize(width: -0.12, height: 0.28)
        case .sleeping:
            return .zero
        case .curious:
            return CGSize(width: 0.34, height: -0.2)
        }
    }

    private func eyeOpenness(for state: PetState) -> CGFloat {
        switch state {
        case .sleeping: return 0.12
        case .success, .celebrating, .love: return 0.42
        case .sad, .error: return 0.72
        case .thinking, .working: return 0.78
        case .curious, .listening: return 1.05
        case .idle: return 1
        }
    }

    private func drawEye(
        context: GraphicsContext,
        in rect: CGRect,
        anchor: CGPoint,
        tilt: Double,
        openness: CGFloat,
        glance: CGSize,
        lift: CGFloat
    ) {
        let length = rect.width * 0.30
        let thickness = max(rect.height * 0.06, rect.height * 0.13 * openness)
        let center = CGPoint(
            x: rect.minX + rect.width * anchor.x,
            y: rect.minY + rect.height * (anchor.y + lift)
        )
        var eye = Path()
        eye.addRoundedRect(
            in: CGRect(x: -length / 2, y: -thickness / 2, width: length, height: thickness),
            cornerSize: CGSize(width: thickness / 2, height: thickness / 2)
        )
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: tilt * .pi / 180)
        let drawn = eye.applying(transform)
        context.fill(drawn, with: .color(PicoTheme.petEyeWhite))

        guard openness > 0.28 else { return }
        let pupilSize = thickness * 0.72
        let pupil = CGRect(
            x: center.x + length * 0.18 * glance.width - pupilSize / 2,
            y: center.y + thickness * 0.8 * glance.height - pupilSize / 2,
            width: pupilSize,
            height: pupilSize
        )
        context.fill(Path(ellipseIn: pupil), with: .color(PicoTheme.petPupil))
        let catch = pupilSize * 0.28
        context.fill(
            Path(ellipseIn: CGRect(x: pupil.minX + pupilSize * 0.18, y: pupil.minY + pupilSize * 0.16, width: catch, height: catch)),
            with: .color(.white.opacity(0.9))
        )
    }

    private func pebblePath(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: point(0.50, 0.08))
        path.addCurve(to: point(0.86, 0.30), control1: point(0.70, 0.02), control2: point(0.84, 0.12))
        path.addCurve(to: point(0.90, 0.62), control1: point(0.96, 0.42), control2: point(0.98, 0.52))
        path.addCurve(to: point(0.58, 0.92), control1: point(0.84, 0.86), control2: point(0.72, 0.98))
        path.addCurve(to: point(0.22, 0.88), control1: point(0.44, 0.98), control2: point(0.30, 0.96))
        path.addCurve(to: point(0.08, 0.54), control1: point(0.10, 0.76), control2: point(0.02, 0.64))
        path.addCurve(to: point(0.20, 0.22), control1: point(0.02, 0.36), control2: point(0.08, 0.24))
        path.addCurve(to: point(0.50, 0.08), control1: point(0.30, 0.10), control2: point(0.38, 0.03))
        path.closeSubpath()
        return path
    }
}
