import SwiftUI

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
        .rotationEffect(metrics.earTilt / 8)
    }

    /// Pico the pencil. The drawing is laid out in the unit square, tilted slightly, and every
    /// expression (eyes, cheeks, mouth) lives on the barrel so it stays readable at 18pt.
    private func drawPet(
        context: GraphicsContext,
        in rect: CGRect,
        metrics: PetAnimationMetrics,
        state: PetState
    ) {
        let w = rect.width
        let h = rect.height
        let mx = rect.midX
        let unit = w / PicoTheme.petSize
        let line = max(unit, 0.6)

        // Pencil body, tilted and slightly shrunk so the tilt never clips the canvas.
        var pencil = context
        pencil.translateBy(x: rect.midX, y: rect.midY)
        pencil.rotate(by: .degrees(-15))
        pencil.scaleBy(x: 0.9, y: 0.9)
        pencil.translateBy(x: -rect.midX, y: -rect.midY)

        // Eraser, then ferrule, barrel, wood and graphite.
        let eraser = Path(
            roundedRect: CGRect(x: mx - 0.23 * w, y: 0.05 * h, width: 0.46 * w, height: 0.14 * h),
            cornerRadius: 0.06 * w
        )
        pencil.fill(eraser, with: .color(PicoTheme.pencilEraser))

        let barrelRect = CGRect(x: mx - 0.25 * w, y: 0.24 * h, width: 0.5 * w, height: 0.48 * h)
        let barrel = Path(roundedRect: barrelRect, cornerRadius: 0.04 * w)
        pencil.fill(barrel, with: .color(PicoTheme.petBody))
        pencil.fill(
            Path(CGRect(x: mx + 0.10 * w, y: barrelRect.minY, width: 0.15 * w, height: barrelRect.height)),
            with: .color(PicoTheme.petBodyShadow.opacity(0.35))
        )
        pencil.stroke(barrel, with: .color(PicoTheme.petBodyShadow.opacity(0.6)), lineWidth: line)

        let ferruleRect = CGRect(x: mx - 0.25 * w, y: 0.17 * h, width: 0.5 * w, height: 0.09 * h)
        pencil.fill(Path(ferruleRect), with: .color(PicoTheme.pencilFerrule))
        for y in [0.195, 0.225] {
            var band = Path()
            band.move(to: CGPoint(x: ferruleRect.minX, y: y * h))
            band.addLine(to: CGPoint(x: ferruleRect.maxX, y: y * h))
            pencil.stroke(band, with: .color(PicoTheme.petBodyShadow.opacity(0.45)), lineWidth: line * 0.7)
        }

        var wood = Path()
        wood.move(to: CGPoint(x: mx - 0.25 * w, y: 0.72 * h))
        wood.addLine(to: CGPoint(x: mx + 0.25 * w, y: 0.72 * h))
        wood.addLine(to: CGPoint(x: mx, y: 0.93 * h))
        wood.closeSubpath()
        pencil.fill(wood, with: .color(PicoTheme.pencilWood))

        var graphite = Path()
        graphite.move(to: CGPoint(x: mx - 0.09 * w, y: 0.855 * h))
        graphite.addLine(to: CGPoint(x: mx + 0.09 * w, y: 0.855 * h))
        graphite.addLine(to: CGPoint(x: mx, y: 0.93 * h))
        graphite.closeSubpath()
        pencil.fill(graphite, with: .color(PicoTheme.pencilGraphite))

        // Eyes
        let eyeCenterY = 0.42 * h
        let eyeHeightFactor: CGFloat = {
            switch state {
            case .sleeping: return 0.03
            case .sad: return 0.08
            default: return 0.12
            }
        }()
        let eyeWidth = max(w * 0.075, 1.4)
        let eyeHeight = max(h * eyeHeightFactor * max(metrics.blinkOpacity, 0.04), 0.4)
        for offset in [-0.10, 0.10] {
            let eye = Ellipse().path(in: CGRect(
                x: mx + offset * w - eyeWidth / 2,
                y: eyeCenterY - eyeHeight / 2,
                width: eyeWidth,
                height: eyeHeight
            ))
            pencil.fill(eye, with: .color(PicoTheme.petEye))
        }

        // Cheeks
        let cheekOpacity: Double = {
            switch state {
            case .love, .celebrating: return 0.9
            case .sad, .sleeping: return 0.3
            default: return 0.6
            }
        }()
        let cheekColor = Color(red: 1.0, green: 0.50, blue: 0.52).opacity(cheekOpacity)
        for offset in [-0.17, 0.17] {
            pencil.fill(
                Ellipse().path(in: CGRect(
                    x: mx + offset * w - 0.045 * w,
                    y: 0.50 * h,
                    width: 0.09 * w,
                    height: 0.055 * h
                )),
                with: .color(cheekColor)
            )
        }

        // Mouth
        var mouth = Path()
        let mouthY = 0.57 * h
        let mouthHalf = max(w * 0.07, 1.4)
        switch state {
        case .error, .sad:
            mouth.addArc(
                center: CGPoint(x: mx, y: mouthY + mouthHalf * 0.9),
                radius: mouthHalf,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: true
            )
        case .success, .listening, .love, .celebrating:
            let big = state == .celebrating || state == .love
            mouth.addArc(
                center: CGPoint(x: mx, y: mouthY - mouthHalf * 0.4),
                radius: mouthHalf * (big ? 1.35 : 1.1),
                startAngle: .degrees(20),
                endAngle: .degrees(160),
                clockwise: false
            )
        case .thinking, .working, .curious:
            let dot = max(3 * unit, 1.2)
            mouth.addEllipse(in: CGRect(x: mx - dot / 2, y: mouthY, width: dot, height: dot))
        case .sleeping:
            mouth.move(to: CGPoint(x: mx - mouthHalf * 0.6, y: mouthY + unit))
            mouth.addLine(to: CGPoint(x: mx + mouthHalf * 0.6, y: mouthY + unit))
        case .idle:
            mouth.move(to: CGPoint(x: mx - mouthHalf, y: mouthY))
            mouth.addQuadCurve(
                to: CGPoint(x: mx + mouthHalf, y: mouthY),
                control: CGPoint(x: mx, y: mouthY + mouthHalf * 0.9)
            )
        }
        pencil.stroke(mouth, with: .color(PicoTheme.petEye), lineWidth: max(1.6 * unit, 0.8))

        // Writing: a little scribble trails the pencil while it works.
        if state == .thinking || state == .working {
            var scribble = Path()
            let baseY = 0.965 * h
            scribble.move(to: CGPoint(x: 0.22 * w, y: baseY))
            for step in 0..<4 {
                let x0 = 0.22 * w + CGFloat(step) * 0.14 * w
                scribble.addQuadCurve(
                    to: CGPoint(x: x0 + 0.14 * w, y: baseY),
                    control: CGPoint(x: x0 + 0.07 * w, y: baseY + (step % 2 == 0 ? -0.05 : 0.05) * h)
                )
            }
            pencil.stroke(
                scribble,
                with: .color(PicoTheme.accent.opacity(state == .working ? 0.6 : 0.9)),
                style: StrokeStyle(lineWidth: max(1.4 * unit, 0.8), lineCap: .round, lineJoin: .round)
            )
        }

        // Extras are drawn upright in the free top-right corner.
        switch state {
        case .love:
            let heart = heartPath(in: CGRect(
                x: rect.minX + w * 0.70,
                y: rect.minY + h * 0.02,
                width: w * 0.22,
                height: h * 0.2
            ))
            context.fill(heart, with: .color(PicoTheme.accent.opacity(0.9)))
        case .success, .celebrating:
            context.fill(
                sparklePath(center: CGPoint(x: rect.minX + w * 0.82, y: rect.minY + h * 0.17), radius: w * 0.14),
                with: .color(PicoTheme.accent)
            )
            if state == .celebrating {
                context.fill(
                    sparklePath(center: CGPoint(x: rect.minX + w * 0.64, y: rect.minY + h * 0.06), radius: w * 0.07),
                    with: .color(PicoTheme.accent.opacity(0.8))
                )
            }
        case .sad, .error:
            context.fill(
                Ellipse().path(in: CGRect(x: rect.minX + w * 0.78, y: rect.minY + h * 0.12, width: w * 0.09, height: h * 0.13)),
                with: .color(Color(red: 0.45, green: 0.70, blue: 0.95))
            )
        case .sleeping:
            context.draw(
                Text("z").font(.system(size: w * 0.22, weight: .bold)),
                at: CGPoint(x: rect.minX + w * 0.82, y: rect.minY + h * 0.14),
                anchor: .center
            )
        case .curious:
            context.draw(
                Text("?").font(.system(size: w * 0.24, weight: .bold)).foregroundColor(PicoTheme.accent),
                at: CGPoint(x: rect.minX + w * 0.82, y: rect.minY + h * 0.14),
                anchor: .center
            )
        default:
            break
        }
    }

    private func sparklePath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let inner = radius * 0.28
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x + inner, y: center.y - inner))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x + inner, y: center.y + inner))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        path.addLine(to: CGPoint(x: center.x - inner, y: center.y + inner))
        path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x - inner, y: center.y - inner))
        path.closeSubpath()
        return path
    }

    private func heartPath(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.35),
            control1: CGPoint(x: rect.midX - w * 0.1, y: rect.maxY - h * 0.2),
            control2: CGPoint(x: rect.minX, y: rect.midY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + h * 0.3),
            control1: CGPoint(x: rect.minX, y: rect.minY),
            control2: CGPoint(x: rect.midX - w * 0.15, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.35),
            control1: CGPoint(x: rect.midX + w * 0.15, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.midY),
            control2: CGPoint(x: rect.midX + w * 0.1, y: rect.maxY - h * 0.2)
        )
        path.closeSubpath()
        return path
    }
}
