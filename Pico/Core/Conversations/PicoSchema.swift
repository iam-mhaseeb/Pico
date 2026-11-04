import Foundation
import SwiftData

/// Version 1 of the on-disk store. When a model changes, add `PicoSchemaV2` and a migration stage.
enum PicoSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Conversation.self, Message.self]
    }
}

enum PicoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PicoSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
