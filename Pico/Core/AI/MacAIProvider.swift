import Foundation
import FoundationModels

final class MacAIProvider: AIProvider, @unchecked Sendable {
    let id = "mac_local"
    let displayName = "On-device AI"

    func availability() async -> Result<Void, AIError> {
        AIAvailability.map(SystemLanguageModel.default.availability)
    }

    func generate(prompt: String, instructions: String?) async throws -> String {
        let availabilityResult = await availability()
        if case .failure(let error) = availabilityResult {
            throw error
        }

        let trimmed = try PromptValidation.validatedPrompt(prompt)

        // A fresh session per request: text actions are independent, one-shot edits.
        let task = Task<String, Error> {
            let session = LanguageModelSession(instructions: instructions ?? "")
            let response = try await session.respond(to: trimmed)
            return response.content
        }

        do {
            // Cancelling the caller (e.g. closing the panel) must reach the unstructured task.
            return try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch is CancellationError {
            throw AIError.cancelled
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.generationFailed
        }
    }
}
