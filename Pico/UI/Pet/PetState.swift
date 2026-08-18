import Foundation

/// Shared pet emotion / activity states used by `PetView` and `PetPanelController`.
enum PetState: String, Sendable, Equatable, CaseIterable {
    // Core Ask / Text Actions loop
    case idle
    case listening
    case thinking
    case success
    case error

    // Gesture + ambient emotions
    case love
    case celebrating
    case sad
    case sleeping
    case curious
    case working

    /// Brief reaction states that auto-return to idle.
    var isTransient: Bool {
        switch self {
        case .success, .error, .love, .celebrating, .sad, .curious:
            true
        case .idle, .listening, .thinking, .sleeping, .working:
            false
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .idle: "Idle"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .success: "Happy"
        case .error: "Something went wrong"
        case .love: "Feeling loved"
        case .celebrating: "Celebrating"
        case .sad: "Sad"
        case .sleeping: "Sleeping"
        case .curious: "Curious"
        case .working: "Working"
        }
    }
}

/// Lightweight transition helper shared by pet UI and panel controller.
enum PetStateMachine {
    /// States Ask Pico / Text Actions may drive.
    static let sessionStates: Set<PetState> = [.listening, .thinking, .working, .success, .error]

    /// Whether `from` may move to `to` without an explicit force.
    static func canTransition(from: PetState, to: PetState) -> Bool {
        if from == to { return true }
        // Session states always win so Ask / Text Actions keep driving the mascot.
        if sessionStates.contains(to) { return true }
        if sessionStates.contains(from), !sessionStates.contains(to), to != .idle {
            // Don't clobber an active Ask/Text session with ambient gestures.
            return from == .success || from == .error
        }
        return true
    }

    static func resolve(current: PetState, requested: PetState, force: Bool = false) -> PetState {
        if force || canTransition(from: current, to: requested) {
            return requested
        }
        return current
    }
}
