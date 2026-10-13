import Foundation

struct SavedPrompt: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var text: String

    init(id: UUID = UUID(), title: String, text: String) {
        self.id = id
        self.title = title
        self.text = text
    }
}

enum SavedPromptStore {
    static let maxCount = 20

    static func load(defaults: UserDefaults = .standard) -> [SavedPrompt] {
        guard let data = defaults.data(forKey: PreferenceKey.savedPrompts),
              let decoded = try? JSONDecoder().decode([SavedPrompt].self, from: data)
        else { return [] }
        return decoded
    }

    static func save(_ prompts: [SavedPrompt], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(prompts) {
            defaults.set(data, forKey: PreferenceKey.savedPrompts)
        }
    }

    @discardableResult
    static func add(title: String, text: String, defaults: UserDefaults = .standard) -> [SavedPrompt] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return load(defaults: defaults) }
        var prompts = load(defaults: defaults)
        prompts.removeAll { $0.text == trimmed }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        prompts.insert(SavedPrompt(title: name.isEmpty ? "Prompt" : name, text: trimmed), at: 0)
        if prompts.count > maxCount {
            prompts = Array(prompts.prefix(maxCount))
        }
        save(prompts, defaults: defaults)
        return prompts
    }

    static func remove(id: UUID, defaults: UserDefaults = .standard) -> [SavedPrompt] {
        var prompts = load(defaults: defaults)
        prompts.removeAll { $0.id == id }
        save(prompts, defaults: defaults)
        return prompts
    }
}
