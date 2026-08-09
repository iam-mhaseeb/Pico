import Foundation
import FoundationModels

enum AIAvailability {
    static func map(_ availability: SystemLanguageModel.Availability) -> Result<Void, AIError> {
        switch availability {
        case .available:
            return .success(())
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .failure(.unavailable(.deviceNotEligible))
            case .appleIntelligenceNotEnabled:
                return .failure(.unavailable(.appleIntelligenceNotEnabled))
            case .modelNotReady:
                return .failure(.unavailable(.modelNotReady))
            default:
                return .failure(.unavailable(.unknown))
            }
        @unknown default:
            return .failure(.unavailable(.unknown))
        }
    }

    static func friendlyMessage(for error: AIError) -> String {
        error.localizedDescription
    }
}
