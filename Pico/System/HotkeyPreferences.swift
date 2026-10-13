import AppKit
import Carbon
import Foundation

struct HotkeyChord: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt32
    var label: String

    static let defaultAsk = HotkeyChord(
        keyCode: UInt16(kVK_Space),
        modifiers: UInt32(optionKey),
        label: "⌥ Space"
    )

    static let defaultText = HotkeyChord(
        keyCode: UInt16(kVK_Space),
        modifiers: UInt32(optionKey | shiftKey),
        label: "⌥ ⇧ Space"
    )

    static func carbonModifiers(from flags: UInt) -> UInt32 {
        var carbon: UInt32 = 0
        let value = NSEvent.ModifierFlags(rawValue: flags)
        if value.contains(.command) { carbon |= UInt32(cmdKey) }
        if value.contains(.option) { carbon |= UInt32(optionKey) }
        if value.contains(.control) { carbon |= UInt32(controlKey) }
        if value.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    static func label(keyCode: UInt16, modifiers: UInt32, characters: String?) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(keyCode: keyCode, characters: characters))
        return parts.joined(separator: " ")
    }

    static func keyName(keyCode: UInt16, characters: String?) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Fwd Delete"
        case kVK_LeftArrow: return "Left"
        case kVK_RightArrow: return "Right"
        case kVK_UpArrow: return "Up"
        case kVK_DownArrow: return "Down"
        default:
            let trimmed = characters?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty { return "Key \(keyCode)" }
            return trimmed.uppercased()
        }
    }
}

enum HotkeyPreferences {
    static func loadAsk(defaults: UserDefaults = .standard) -> HotkeyChord {
        load(key: PreferenceKey.askHotkey, fallback: .defaultAsk, defaults: defaults)
    }

    static func loadText(defaults: UserDefaults = .standard) -> HotkeyChord {
        load(key: PreferenceKey.textHotkey, fallback: .defaultText, defaults: defaults)
    }

    static func saveAsk(_ chord: HotkeyChord, defaults: UserDefaults = .standard) {
        save(chord, key: PreferenceKey.askHotkey, defaults: defaults)
    }

    static func saveText(_ chord: HotkeyChord, defaults: UserDefaults = .standard) {
        save(chord, key: PreferenceKey.textHotkey, defaults: defaults)
    }

    private static func load(key: String, fallback: HotkeyChord, defaults: UserDefaults) -> HotkeyChord {
        guard let data = defaults.data(forKey: key),
              let chord = try? JSONDecoder().decode(HotkeyChord.self, from: data),
              !chord.label.isEmpty
        else { return fallback }
        return chord
    }

    private static func save(_ chord: HotkeyChord, key: String, defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(chord) {
            defaults.set(data, forKey: key)
        }
    }
}
