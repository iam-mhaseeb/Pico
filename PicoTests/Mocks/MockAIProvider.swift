import Foundation
@testable import Pico

/// Configurable AI provider for unit tests — no Foundation Models required.
final class MockAIProvider: AIProvider, @unchecked Sendable {
    let id = "mock"
    let displayName = "Mock AI"

    private let lock = NSLock()
    var generateResult = "generated"
    var generateError: AIError?
    var availabilityResult: Result<Void, AIError> = .success(())
    private(set) var prompts: [String] = []

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func availability() async -> Result<Void, AIError> {
        withLock { availabilityResult }
    }

    func generate(prompt: String, instructions: String?) async throws -> String {
        withLock { prompts.append(prompt) }
        let error = withLock { generateError }
        if let error { throw error }
        return withLock { generateResult }
    }
}
