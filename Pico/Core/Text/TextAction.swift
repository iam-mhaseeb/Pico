import Foundation
import SwiftUI

enum TextAction: String, CaseIterable, Identifiable, Sendable {
    case rewrite
    case fixGrammar
    case makeProfessional
    case makeCasual
    case makeShorter
    case improve

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rewrite: return "Rewrite"
        case .fixGrammar: return "Fix grammar & spelling"
        case .makeProfessional: return "Make professional"
        case .makeCasual: return "Make casual"
        case .makeShorter: return "Make shorter"
        case .improve: return "Improve"
        }
    }

    var symbolName: String {
        switch self {
        case .rewrite: return "sparkles"
        case .fixGrammar: return "checkmark.circle"
        case .makeProfessional: return "briefcase"
        case .makeCasual: return "face.smiling"
        case .makeShorter: return "scissors"
        case .improve: return "arrow.up.circle"
        }
    }
}
