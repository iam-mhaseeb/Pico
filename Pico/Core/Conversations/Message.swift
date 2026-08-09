import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var conversation: Conversation?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = .now,
        conversation: Conversation? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.conversation = conversation
    }
}
