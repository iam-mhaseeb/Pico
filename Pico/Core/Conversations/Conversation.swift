import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var providerID: String
    var modelName: String?
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]

    init(
        id: UUID = UUID(),
        title: String = "New conversation",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        providerID: String = "mac_local",
        modelName: String? = nil,
        messages: [Message] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerID = providerID
        self.modelName = modelName
        self.messages = messages
    }
}
