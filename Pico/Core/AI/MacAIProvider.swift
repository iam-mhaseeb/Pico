import Foundation
import FoundationModels

final class MacAIProvider: AIProvider, @unchecked Sendable {
    let id = "mac_local"
    let displayName = "On-device AI"

    private static let maxPromptCharacters = 12_000

    private let lock = NSLock()
    private var sessions: [UUID: LanguageModelSession] = [:]
    private var streamTasks: [UUID: Task<Void, Never>] = [:]
    private var generateTask: Task<String, Error>?
    private var seededHistories: [UUID: [(role: String, content: String)]] = [:]

    func availability() async -> Result<Void, AIError> {
        AIAvailability.map(SystemLanguageModel.default.availability)
    }

    func seedHistory(sessionID: UUID, messages: [(role: String, content: String)]) {
        lock.lock()
        seededHistories[sessionID] = messages.filter { $0.role == "user" || $0.role == "assistant" }
        // Always recreate so reload doesn't double-append onto a live transcript.
        sessions[sessionID] = LanguageModelSession(instructions: PromptTemplates.askPersonality)
        lock.unlock()
    }

    func dropSession(sessionID: UUID) {
        lock.lock()
        streamTasks[sessionID]?.cancel()
        streamTasks[sessionID] = nil
        sessions[sessionID] = nil
        seededHistories[sessionID] = nil
        lock.unlock()
    }

    func stream(
        prompt: String,
        sessionID: UUID?,
        instructions: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let availabilityResult = await self.availability()
                    if case .failure(let error) = availabilityResult {
                        continuation.finish(throwing: error)
                        return
                    }

                    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else {
                        continuation.finish(throwing: AIError.emptyPrompt)
                        return
                    }
                    guard trimmed.count <= Self.maxPromptCharacters else {
                        continuation.finish(throwing: AIError.inputTooLarge)
                        return
                    }

                    let promptToSend = self.promptIncludingSeededHistory(
                        sessionID: sessionID,
                        prompt: trimmed
                    )

                    let session: LanguageModelSession
                    if let sessionID {
                        session = self.session(
                            for: sessionID,
                            instructions: instructions ?? PromptTemplates.askPersonality
                        )
                    } else {
                        // Ephemeral — do not retain in the session map.
                        session = LanguageModelSession(
                            instructions: instructions ?? PromptTemplates.askPersonality
                        )
                    }

                    let responseStream = session.streamResponse(to: promptToSend)
                    for try await snapshot in responseStream {
                        if Task.isCancelled {
                            if let sessionID {
                                self.resetSession(sessionID)
                            }
                            continuation.finish(throwing: AIError.cancelled)
                            return
                        }
                        continuation.yield(snapshot.content)
                    }
                    self.clearSeededHistory(for: sessionID)
                    continuation.finish()
                } catch is CancellationError {
                    if let sessionID {
                        self.resetSession(sessionID)
                    }
                    continuation.finish(throwing: AIError.cancelled)
                } catch let error as AIError {
                    if let sessionID {
                        self.resetSession(sessionID)
                    }
                    continuation.finish(throwing: error)
                } catch {
                    if let sessionID {
                        self.resetSession(sessionID)
                    }
                    continuation.finish(throwing: AIError.generationFailed)
                }
            }

            if let sessionID {
                self.storeStreamTask(task, for: sessionID)
            }

            continuation.onTermination = { _ in
                task.cancel()
                if let sessionID {
                    self.clearStreamTask(for: sessionID)
                }
            }
        }
    }

    func generate(prompt: String, instructions: String?) async throws -> String {
        let availabilityResult = await availability()
        if case .failure(let error) = availabilityResult {
            throw error
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.emptyPrompt }
        guard trimmed.count <= Self.maxPromptCharacters else { throw AIError.inputTooLarge }

        generateTask?.cancel()
        let task = Task {
            let session = LanguageModelSession(
                instructions: instructions ?? PromptTemplates.askPersonality
            )
            let response = try await session.respond(to: trimmed)
            return response.content
        }
        generateTask = task

        do {
            let value = try await task.value
            generateTask = nil
            return value
        } catch is CancellationError {
            generateTask = nil
            throw AIError.cancelled
        } catch let error as AIError {
            generateTask = nil
            throw error
        } catch {
            generateTask = nil
            throw AIError.generationFailed
        }
    }

    func cancel(sessionID: UUID?) {
        // Cancel in-flight work only. Do not drop the live session — closing Ask
        // or stopping a stream task must not wipe multi-turn context.
        // Mid-stream failures still call resetSession from the stream loop.
        lock.lock()
        if let sessionID {
            streamTasks[sessionID]?.cancel()
            streamTasks[sessionID] = nil
        } else {
            for (_, task) in streamTasks {
                task.cancel()
            }
            streamTasks.removeAll()
            generateTask?.cancel()
            generateTask = nil
        }
        lock.unlock()
    }

    private func session(for key: UUID, instructions: String) -> LanguageModelSession {
        lock.lock()
        defer { lock.unlock() }
        if let existing = sessions[key] {
            return existing
        }
        let created = LanguageModelSession(instructions: instructions)
        sessions[key] = created
        return created
    }

    private func resetSession(_ sessionID: UUID) {
        lock.lock()
        sessions[sessionID] = nil
        lock.unlock()
    }

    private func promptIncludingSeededHistory(sessionID: UUID?, prompt: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let sessionID, let history = seededHistories[sessionID], !history.isEmpty else {
            return prompt
        }
        // Seed only once — next turns use the live LanguageModelSession transcript.
        seededHistories[sessionID] = nil
        let historyBlock = history.map { message in
            "\(message.role): \(message.content)"
        }.joined(separator: "\n")
        return """
        Previous conversation:
        \(historyBlock)

        User:
        \(prompt)
        """
    }

    private func clearSeededHistory(for sessionID: UUID?) {
        guard let sessionID else { return }
        lock.lock()
        seededHistories[sessionID] = nil
        lock.unlock()
    }

    private func storeStreamTask(_ task: Task<Void, Never>, for sessionID: UUID) {
        lock.lock()
        streamTasks[sessionID]?.cancel()
        streamTasks[sessionID] = task
        lock.unlock()
    }

    private func clearStreamTask(for sessionID: UUID) {
        lock.lock()
        streamTasks[sessionID] = nil
        lock.unlock()
    }
}
