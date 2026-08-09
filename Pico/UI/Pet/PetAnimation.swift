import SwiftUI

struct PetAnimationMetrics {
    let breatheScale: CGFloat
    let blinkOpacity: Double
    let bounceOffset: CGFloat
    let earTilt: Angle

    static func metrics(
        for state: PetState,
        date: Date,
        reduceMotion: Bool
    ) -> PetAnimationMetrics {
        if reduceMotion {
            return PetAnimationMetrics(
                breatheScale: 1,
                blinkOpacity: 1,
                bounceOffset: 0,
                earTilt: .degrees(state == .listening ? -6 : 0)
            )
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
                earTilt: .degrees(sin(time * 0.6) * 3)
            )
        case .listening:
            return PetAnimationMetrics(
                breatheScale: 1.04,
                blinkOpacity: 1,
                bounceOffset: sin(time * 6) * 1.5,
                earTilt: .degrees(-10)
            )
        case .thinking:
            return PetAnimationMetrics(
                breatheScale: 1 + 0.04 * sin(time * 5),
                blinkOpacity: 1,
                bounceOffset: sin(time * 4) * 2,
                earTilt: .degrees(sin(time * 8) * 8)
            )
        case .success:
            return PetAnimationMetrics(
                breatheScale: 1.08,
                blinkOpacity: 1,
                bounceOffset: -3,
                earTilt: .degrees(8)
            )
        case .error:
            return PetAnimationMetrics(
                breatheScale: 0.96,
                blinkOpacity: 1,
                bounceOffset: sin(time * 14) * 1.2,
                earTilt: .degrees(-4)
            )
        }
    }
}
