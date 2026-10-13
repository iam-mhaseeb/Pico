import AppKit
import Foundation

enum ScreenAllowlist {
    struct AppEntry: Codable, Identifiable, Equatable, Sendable {
        var bundleID: String
        var name: String
        var id: String { bundleID }
    }

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: PreferenceKey.screenAllowlistEnabled)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: PreferenceKey.screenAllowlistEnabled)
    }

    static func apps(defaults: UserDefaults = .standard) -> [AppEntry] {
        guard let data = defaults.data(forKey: PreferenceKey.screenAllowlistApps),
              let decoded = try? JSONDecoder().decode([AppEntry].self, from: data)
        else { return [] }
        return decoded
    }

    static func save(_ apps: [AppEntry], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(apps) {
            defaults.set(data, forKey: PreferenceKey.screenAllowlistApps)
        }
    }

    static func allows(bundleID: String?, defaults: UserDefaults = .standard) -> Bool {
        guard isEnabled(defaults: defaults) else { return true }
        guard let bundleID, !bundleID.isEmpty else { return false }
        return apps(defaults: defaults).contains { $0.bundleID == bundleID }
    }

    static func blockMessage(bundleID: String?, appName: String, defaults: UserDefaults = .standard) -> String? {
        guard !allows(bundleID: bundleID, defaults: defaults) else { return nil }
        return "Pico isn’t allowed to control \(appName). Add it in Settings → Screen control."
    }

    static func runningApps() -> [AppEntry] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier, let name = app.localizedName else { return nil }
                return AppEntry(bundleID: bundleID, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
