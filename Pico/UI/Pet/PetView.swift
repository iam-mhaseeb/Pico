import SwiftUI

struct PetFaceView: View {
    let state: PetState
    var size: CGFloat = PicoTheme.petSize
    /// Extra squash from hover acknowledgements (1 = none).
    var hoverSquash: CGFloat = 1
    var outfit: PetSeasonOutfit = .none
    var showBow: Bool = false
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
            x: metrics.breatheScale * metrics.squashX * hoverSquash,
            y: metrics.breatheScale * metrics.squashY / max(hoverSquash, 0.01)
        )
        .offset(y: metrics.bounceOffset)
        .rotationEffect(metrics.earTilt / 8)
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
        let eyeHeightFactor: CGFloat = {
            switch state {
            case .sleeping: return 0.04
            case .sad: return 0.09
            default: return 0.13
            }
        }()
        let eyeSize = CGSize(
            width: rect.width * 0.11,
            height: rect.height * eyeHeightFactor * max(metrics.blinkOpacity, 0.04)
        )
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

        let cheekOpacity: Double = {
            switch state {
            case .love, .celebrating: return 0.85
            case .sad, .sleeping: return 0.25
            default: return 0.55
            }
        }()
        let cheekSize = CGSize(width: rect.width * 0.12, height: rect.height * 0.08)
        let cheekColor = Color(red: 1.0, green: 0.55, blue: 0.55).opacity(cheekOpacity)
        context.fill(
            Ellipse().path(in: CGRect(x: rect.midX - rect.width * 0.28, y: rect.midY + rect.height * 0.05, width: cheekSize.width, height: cheekSize.height)),
            with: .color(cheekColor)
        )
        context.fill(
            Ellipse().path(in: CGRect(x: rect.midX + rect.width * 0.16, y: rect.midY + rect.height * 0.05, width: cheekSize.width, height: cheekSize.height)),
            with: .color(cheekColor)
        )

        var mouth = Path()
        let mouthY = rect.midY + rect.height * 0.16
        switch state {
        case .error, .sad:
            mouth.addArc(
                center: CGPoint(x: rect.midX, y: mouthY + 4),
                radius: rect.width * 0.08,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: true
            )
        case .success, .listening, .love, .celebrating:
            mouth.addArc(
                center: CGPoint(x: rect.midX, y: mouthY - 2),
                radius: rect.width * (state == .celebrating || state == .love ? 0.11 : 0.09),
                startAngle: .degrees(20),
                endAngle: .degrees(160),
                clockwise: false
            )
        case .thinking, .working, .curious:
            mouth.addEllipse(in: CGRect(x: rect.midX - 2, y: mouthY, width: 4, height: 4))
        case .sleeping:
            mouth.move(to: CGPoint(x: rect.midX - 4, y: mouthY + 1))
            mouth.addLine(to: CGPoint(x: rect.midX + 4, y: mouthY + 1))
        case .idle:
            mouth.move(to: CGPoint(x: rect.midX - 6, y: mouthY))
            mouth.addQuadCurve(
                to: CGPoint(x: rect.midX + 6, y: mouthY),
                control: CGPoint(x: rect.midX, y: mouthY + 4)
            )
        }
        context.stroke(mouth, with: .color(PicoTheme.petEye), lineWidth: 1.8)

        if state == .thinking || state == .working {
            let dotY = rect.minY + rect.height * 0.08
            for index in 0..<3 {
                let x = rect.midX + CGFloat(index - 1) * 7
                context.fill(
                    Circle().path(in: CGRect(x: x, y: dotY, width: 3.5, height: 3.5)),
                    with: .color(PicoTheme.accent.opacity(state == .working ? 0.55 : 0.8))
                )
            }
        }

        if state == .love {
            let heart = heartPath(in: CGRect(
                x: rect.midX + rect.width * 0.18,
                y: rect.minY + rect.height * 0.02,
                width: rect.width * 0.16,
                height: rect.height * 0.14
            ))
            context.fill(heart, with: .color(PicoTheme.accent.opacity(0.9)))
        }

        if state == .sleeping {
            context.draw(
                Text("z"),
                at: CGPoint(x: rect.midX + rect.width * 0.22, y: rect.minY + rect.height * 0.12),
                anchor: .center
            )
        }

        drawOutfit(context: context, in: rect)
    }

    private func drawOutfit(context: GraphicsContext, in rect: CGRect) {
        switch outfit {
        case .none:
            break
        case .winterScarf:
            var scarf = Path()
            scarf.addRoundedRect(
                in: CGRect(
                    x: rect.minX + rect.width * 0.22,
                    y: rect.midY + rect.height * 0.18,
                    width: rect.width * 0.56,
                    height: rect.height * 0.12
                ),
                cornerSize: CGSize(width: 4, height: 4)
            )
            context.fill(scarf, with: .color(Color(red: 0.75, green: 0.22, blue: 0.24)))
        case .spooky:
            var hat = Path()
            hat.move(to: CGPoint(x: rect.midX, y: rect.minY + 1))
            hat.addLine(to: CGPoint(x: rect.midX - rect.width * 0.16, y: rect.minY + rect.height * 0.2))
            hat.addLine(to: CGPoint(x: rect.midX + rect.width * 0.16, y: rect.minY + rect.height * 0.2))
            hat.closeSubpath()
            context.fill(hat, with: .color(Color(red: 0.35, green: 0.22, blue: 0.55)))
        case .celebration:
            var cone = Path()
            cone.move(to: CGPoint(x: rect.midX, y: rect.minY))
            cone.addLine(to: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.height * 0.22))
            cone.addLine(to: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.minY + rect.height * 0.22))
            cone.closeSubpath()
            context.fill(cone, with: .color(PicoTheme.accent))
        }

        if showBow {
            let bow = Circle().path(
                in: CGRect(
                    x: rect.midX - 4,
                    y: rect.midY + rect.height * 0.22,
                    width: 8,
                    height: 8
                )
            )
            context.fill(bow, with: .color(Color(red: 0.85, green: 0.25, blue: 0.45)))
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

struct PetView: View {
    @Bindable var coordinator: AppCoordinator
    var bubbleText: String?
    var bubbleBelow: Bool = false
    var hoverSquash: CGFloat = 1
    var outfit: PetSeasonOutfit = .none
    var showBow: Bool = false
    var animationInterval: TimeInterval = 1.0 / 20.0
    var pauseAnimation: Bool = false
    var toastText: String?
    var onDismissToast: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 2) {
            if let toastText, !bubbleBelow {
                PetSpeechBubbleView(text: toastText, placeBelow: false, onDismiss: onDismissToast)
                    .frame(height: PetPanelController.bubbleSlotHeight - 2)
            } else if let bubbleText, !bubbleBelow {
                PetSpeechBubbleView(text: bubbleText, placeBelow: false)
                    .frame(height: PetPanelController.bubbleSlotHeight - 2)
            }

            PetFaceView(
                state: coordinator.petState,
                size: PicoTheme.petSize,
                hoverSquash: hoverSquash,
                outfit: outfit,
                showBow: showBow,
                animationInterval: animationInterval,
                pauseAnimation: pauseAnimation
            )
            .frame(width: PicoTheme.petSize, height: PicoTheme.petSize)
            .animation(
                reduceMotion
                    ? nil
                    : .interpolatingSpring(stiffness: 380, damping: 18),
                value: hoverSquash
            )

            if let toastText, bubbleBelow {
                PetSpeechBubbleView(text: toastText, placeBelow: true, onDismiss: onDismissToast)
                    .frame(height: PetPanelController.bubbleSlotHeight - 2)
            } else if let bubbleText, bubbleBelow {
                PetSpeechBubbleView(text: bubbleText, placeBelow: true)
                    .frame(height: PetPanelController.bubbleSlotHeight - 2)
            }
        }
        .frame(
            width: (bubbleText == nil && toastText == nil)
                ? PicoTheme.petSize
                : max(PicoTheme.petSize, PicoTheme.petBubbleSize),
            height: PicoTheme.petSize + (bubbleText == nil && toastText == nil ? 0 : PetPanelController.bubbleSlotHeight),
            alignment: bubbleBelow ? .top : .bottom
        )
        .background(Color.clear)
        // Drag, click, and context menu are handled by DraggablePetContainer.
    }
}
