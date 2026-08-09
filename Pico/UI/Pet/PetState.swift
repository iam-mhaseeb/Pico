import Foundation

enum PetState: String, Sendable, Equatable {
    case idle
    case listening
    case thinking
    case success
    case error
}
