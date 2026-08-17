import Foundation
import SwiftData
@testable import Pico

enum TestModelContainerFactory {
    static func inMemory() throws -> ModelContainer {
        let schema = Schema([Conversation.self, Message.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func onDisk() throws -> (ModelContainer, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PicoTests-\(UUID().uuidString).store")
        let schema = Schema([Conversation.self, Message.self])
        let configuration = ModelConfiguration(url: url)
        return (try ModelContainer(for: schema, configurations: [configuration]), url)
    }

    static func removeStore(at url: URL) {
        let base = url.path
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(atPath: base + "-shm")
        try? FileManager.default.removeItem(atPath: base + "-wal")
    }
}

enum TestUserDefaults {
    static func setKeepHistory(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: PreferenceKey.keepHistory)
    }

    static func resetKeepHistory() {
        UserDefaults.standard.removeObject(forKey: PreferenceKey.keepHistory)
    }
}
