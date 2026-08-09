import Foundation
import FoundationModels

final class MacAIProvider: AIProvider, @unchecked Sendable {
    let id = "mac_local"
    let displayName = "On-device AI"

    private let lock = NSLock()
    private var sessions: [UUID: LanguageModelSession] = [:]
    private var streamTasks: [UUID: Task<Void, Never>] = [:]
    private var seededHistories: [UUID: [(role: String, content: String)]] = [:]

    func availability() async -> Result<Void, AIError> {
        AIAvailability.map(SystemLanguageModel.default.availability)
    }

    func seedHistory(sessionID: UUID, messages: [(role: String, content: String)]) {
        lock.lock()
        seededHistories[sessionID] = messages
        if sessions[sessionID] == nil {
            sessions[sessionID] = LanguageModelSession(instructions: PromptTemplates.askPersonality)
        }
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

                    let key = sessionID ?? UUID()
                    let session = self.session(
                        for: key,
                        instructions: instructions ?? PromptTemplates.askPersonality
                    )
                    let promptToSend = self.promptIncludingSeededHistory(
                        sessionID: sessionID,
                        prompt: trimmed
                    )

                    let responseStream = session.streamResponse(to: promptToSend)
                    for try await snapshot in responseStream {
                        if Task.isCancelled {
                            continuation.finish(throwing: AIError.cancelled)
                            return
                        }
                        continuation.yield(snapshot.content)
                    }
                    self.clearSeededHistory(for: sessionID)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIError.cancelled)
                } catch let error as AIError {
                    continuation.finish(throwing: error)
                } catch {
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

        let session = LanguageModelSession(
            instructions: instructions ?? PromptTemplates.askPersonality
        )

        do {
            let response = try await session.respond(to: trimmed)
            return response.content
        } catch is CancellationError {
            throw AIError.cancelled
        } catch {
            throw AIError.generationFailed
        }
    }

    func cancel(sessionID: UUID?) {
        lock.lock()
        if let sessionID {
            streamTasks[sessionID]?.cancel()
            streamTasks[sessionID] = nil
        } else {
            for (_, task) in streamTasks {
                task.cancel()
            }
            streamTasks.removeAll()
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

    private func promptIncludingSeededHistory(sessionID: UUID?, prompt: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let sessionID, let history = seededHistories[sessionID], !history.isEmpty else {
            return prompt
        }
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
