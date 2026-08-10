import SwiftUI

struct PetAnimationMetrics {
    let breatheScale: CGFloat
    let blinkOpacity: Double
    let bounceOffset: CGFloat
    let earTilt: Angle
    /// Horizontal squash (1 = normal). Used for hover / celebrate stretch.
    let squashX: CGFloat
    /// Vertical stretch (1 = normal).
    let squashY: CGFloat

    static let identity = PetAnimationMetrics(
        breatheScale: 1,
        blinkOpacity: 1,
        bounceOffset: 0,
        earTilt: .degrees(0),
        squashX: 1,
        squashY: 1
    )

    static func metrics(
        for state: PetState,
        date: Date,
        reduceMotion: Bool
    ) -> PetAnimationMetrics {
        if reduceMotion {
            return reducedMotionMetrics(for: state)
        }

        let time = date.timeIntervalSinceReferenceDate
        switch state {
        case .idle:
            let breathe = 1 + 0.03 * sin(time * 2.2)
            let blinkPhase = time.truncatingRemainder(dividingBy: 3.8)
            let blink = blinkPhase < 0.12 ? 0.08 : 1.0
            return PetAnimationMetrics(
                breatheScale: breathe,
                blinkOpacity: blink,
                bounceOffset: 0,
                earTilt: .degrees(sin(time * 0.6) * 3),
                squashX: 1,
                squashY: 1
            )
        case .listening:
            return PetAnimationMetrics(
                breatheScale: 1.04,
                blinkOpacity: 1,
                bounceOffset: sin(time * 6) * 1.5,
                earTilt: .degrees(-10),
                squashX: 1,
                squashY: 1
            )
        case .thinking:
            return PetAnimationMetrics(
                breatheScale: 1 + 0.04 * sin(time * 5),
                blinkOpacity: 1,
                bounceOffset: sin(time * 4) * 2,
                earTilt: .degrees(sin(time * 8) * 8),
                squashX: 1,
                squashY: 1
            )
        case .success:
            return PetAnimationMetrics(
                breatheScale: 1.08,
                blinkOpacity: 1,
                bounceOffset: -3,
                earTilt: .degrees(8),
                squashX: 1,
                squashY: 1
            )
        case .error:
            return PetAnimationMetrics(
                breatheScale: 0.96,
                blinkOpacity: 1,
                bounceOffset: sin(time * 14) * 1.2,
                earTilt: .degrees(-4),
                squashX: 1,
                squashY: 1
            )
        case .love:
            let pulse = 1 + 0.06 * abs(sin(time * 8))
            return PetAnimationMetrics(
                breatheScale: pulse,
                blinkOpacity: 1,
                bounceOffset: sin(time * 10) * 2,
                earTilt: .degrees(sin(time * 6) * 10),
                squashX: 1.04,
                squashY: 0.96
            )
        case .celebrating:
            return PetAnimationMetrics(
                breatheScale: 1.1,
                blinkOpacity: 1,
                bounceOffset: -abs(sin(time * 12)) * 6,
                earTilt: .degrees(sin(time * 14) * 14),
                squashX: 0.92 + 0.08 * abs(sin(time * 12)),
                squashY: 1.08 - 0.08 * abs(sin(time * 12))
            )
        case .sad:
            return PetAnimationMetrics(
                breatheScale: 0.94,
                blinkOpacity: 0.85,
                bounceOffset: 2,
                earTilt: .degrees(-12),
                squashX: 1.06,
                squashY: 0.94
            )
        case .sleeping:
            let breathe = 1 + 0.02 * sin(time * 1.2)
            return PetAnimationMetrics(
                breatheScale: breathe,
                blinkOpacity: 0.05,
                bounceOffset: 1,
                earTilt: .degrees(-6),
                squashX: 1.02,
                squashY: 0.98
            )
        case .curious:
            return PetAnimationMetrics(
                breatheScale: 1.03,
                blinkOpacity: 1,
                bounceOffset: sin(time * 5) * 1.5,
                earTilt: .degrees(12 + sin(time * 3) * 4),
                squashX: 0.98,
                squashY: 1.04
            )
        case .working:
            return PetAnimationMetrics(
                breatheScale: 1 + 0.025 * sin(time * 3.5),
                blinkOpacity: 1,
                bounceOffset: 0,
                earTilt: .degrees(sin(time * 2.4) * 5),
                squashX: 1,
                squashY: 1
            )
        }
    }

    private static func reducedMotionMetrics(for state: PetState) -> PetAnimationMetrics {
        switch state {
        case .listening:
            return PetAnimationMetrics(
                breatheScale: 1,
                blinkOpacity: 1,
                bounceOffset: 0,
                earTilt: .degrees(-6),
                squashX: 1,
                squashY: 1
            )
        case .love, .celebrating, .success:
            return PetAnimationMetrics(
                breatheScale: 1.04,
                blinkOpacity: 1,
                bounceOffset: 0,
                earTilt: .degrees(4),
                squashX: 1,
                squashY: 1
            )
        case .sad, .error:
            return PetAnimationMetrics(
                breatheScale: 0.97,
                blinkOpacity: 1,
                bounceOffset: 0,
                earTilt: .degrees(-4),
                squashX: 1,
                squashY: 1
            )
        case .sleeping:
            return PetAnimationMetrics(
                breatheScale: 1,
                blinkOpacity: 0.1,
                bounceOffset: 0,
                earTilt: .degrees(-4),
                squashX: 1,
                squashY: 1
            )
        case .curious:
            return PetAnimationMetrics(
                breatheScale: 1,
                blinkOpacity: 1,
                bounceOffset: 0,
                earTilt: .degrees(8),
                squashX: 1,
                squashY: 1
            )
        case .idle, .thinking, .working:
            return .identity
        }
    }
}
