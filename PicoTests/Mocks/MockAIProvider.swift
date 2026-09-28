import Foundation
@testable import Pico

/// Configurable AI provider for unit tests — no Foundation Models required.
final class MockAIProvider: AIProvider, @unchecked Sendable {
    let id = "mock"
    let displayName = "Mock AI"

    private let lock = NSLock()
    var streamChunks: [String] = []
    var streamError: AIError?
    var generateResult = "generated"
    var generateError: AIError?
    var availabilityResult: Result<Void, AIError> = .success(())

    var cancelCallCount = 0
    var droppedSessionIDs: [UUID] = []
    var seededHistories: [(UUID, [(role: String, content: String)])] = []
    var activeSessionIDs: Set<UUID> = []
    var lastPrompts: [String] = []
    var lastExtraContext: String?

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func availability() async -> Result<Void, AIError> {
        withLock { availabilityResult }
    }

    func stream(
        prompt: String,
        sessionID: UUID?,
        instructions: String?,
        extraContext: String?,
        toneHint: String?
    ) -> AsyncThrowingStream<String, Error> {
        let chunks = withLock { streamChunks }
        let error = withLock { streamError }
        withLock {
            lastPrompts.append(prompt)
            lastExtraContext = extraContext
        }
        if let sessionID {
            withLock { activeSessionIDs.insert(sessionID) }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                for chunk in chunks {
                    if Task.isCancelled {
                        continuation.finish(throwing: AIError.cancelled)
                        return
                    }
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func generate(prompt: String, instructions: String?) async throws -> String {
        let error = withLock { generateError }
        if let error { throw error }
        return withLock { generateResult }
    }

    func cancel(sessionID: UUID?) {
        withLock { cancelCallCount += 1 }
    }

    func seedHistory(sessionID: UUID, messages: [(role: String, content: String)]) {
        withLock {
            seededHistories.append((sessionID, messages))
            activeSessionIDs.insert(sessionID)
        }
    }

    func dropSession(sessionID: UUID) {
        withLock {
            droppedSessionIDs.append(sessionID)
            activeSessionIDs.remove(sessionID)
        }
    }

    func sessionIsActive(_ sessionID: UUID) -> Bool {
        withLock { activeSessionIDs.contains(sessionID) }
    }
}
