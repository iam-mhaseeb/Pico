import XCTest
@testable import Pico

final class PetStateMachineTests: XCTestCase {
    func testAllExpandedStatesExist() {
        let required: Set<PetState> = [
            .idle, .listening, .thinking, .success, .error,
            .love, .celebrating, .sad, .sleeping, .curious, .working
        ]
        XCTAssertEqual(Set(PetState.allCases), required)
    }

    func testSessionStatesAlwaysAccepted() {
        XCTAssertEqual(
            PetStateMachine.resolve(current: .idle, requested: .listening),
            .listening
        )
        XCTAssertEqual(
            PetStateMachine.resolve(current: .love, requested: .thinking),
            .thinking
        )
        XCTAssertEqual(
            PetStateMachine.resolve(current: .sleeping, requested: .error),
            .error
        )
    }

    func testAmbientGestureDoesNotInterruptActiveSession() {
        XCTAssertEqual(
            PetStateMachine.resolve(current: .listening, requested: .love),
            .listening
        )
        XCTAssertEqual(
            PetStateMachine.resolve(current: .thinking, requested: .celebrating),
            .thinking
        )
        XCTAssertEqual(
            PetStateMachine.resolve(current: .working, requested: .love),
            .working
        )
    }

    func testForceOverridesSessionGuard() {
        XCTAssertEqual(
            PetStateMachine.resolve(current: .listening, requested: .idle, force: true),
            .idle
        )
    }

    func testTransientFlags() {
        XCTAssertTrue(PetState.love.isTransient)
        XCTAssertTrue(PetState.celebrating.isTransient)
        XCTAssertTrue(PetState.sad.isTransient)
        XCTAssertFalse(PetState.sleeping.isTransient)
        XCTAssertFalse(PetState.working.isTransient)
        XCTAssertFalse(PetState.listening.isTransient)
    }

    func testAnimationMetricsCoverNewStates() {
        let date = Date(timeIntervalSinceReferenceDate: 10)
        for state in PetState.allCases {
            let metrics = PetAnimationMetrics.metrics(for: state, date: date, reduceMotion: false)
            XCTAssertGreaterThan(metrics.breatheScale, 0)
            let reduced = PetAnimationMetrics.metrics(for: state, date: date, reduceMotion: true)
            XCTAssertGreaterThan(reduced.breatheScale, 0)
        }
    }
}
