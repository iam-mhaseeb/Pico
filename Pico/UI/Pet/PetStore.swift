import Foundation

struct PetStoredSettings: Codable, Equatable, Sendable {
    var chaseEnabled: Bool
    var wanderEnabled: Bool
    var toysEnabled: Bool
    var careEnabled: Bool
    var persona: PetPersona
    var routine: DayRoutine
    var autoSeason: Bool
    var xpEnabled: Bool
    var performanceEnabled: Bool
    var performanceOnBattery: Bool
    var soundVolume: Double
    var mutedSounds: [String]
    var sessionBubbles: Bool
    var focusBlocks: [FocusBlock]
    var moodOverrides: [String: String]
    var stats: CareStats
    var progression: PetProgression
    var usage: UsageCounters
    var lastStretchDay: String?

    static let `default` = PetStoredSettings(
        chaseEnabled: true,
        wanderEnabled: false,
        toysEnabled: true,
        careEnabled: true,
        persona: .friendly,
        routine: .default,
        autoSeason: true,
        xpEnabled: true,
        performanceEnabled: false,
        performanceOnBattery: false,
        soundVolume: 0,
        mutedSounds: [],
        sessionBubbles: true,
        focusBlocks: [],
        moodOverrides: [:],
        stats: .initial(at: .distantPast),
        progression: PetProgression(),
        usage: UsageCounters(),
        lastStretchDay: nil
    )

    var moodMap: [String: PetContextMood] {
        moodOverrides.compactMapValues(PetContextMood.init(rawValue:))
    }
}

enum PetStore {
    static let settingsKey = "petCompanionSettings"

    static func load(from defaults: UserDefaults = .standard) -> PetStoredSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(PetStoredSettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    static func save(_ settings: PetStoredSettings, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}
