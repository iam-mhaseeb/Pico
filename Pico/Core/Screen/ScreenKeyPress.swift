import Carbon
import CoreGraphics
import Foundation

struct ScreenKeyPress: Equatable {
    var keyCode: UInt16
    var flags: CGEventFlags
}

enum ScreenKeyPressParser {
    enum ParseError: LocalizedError, Equatable {
        case empty
        case unknownKey(String)

        var errorDescription: String? {
            switch self {
            case .empty:
                return "No key specified."
            case .unknownKey(let name):
                return "I don’t know the key “\(name)”."
            }
        }
    }

    static func parse(_ spec: String) throws -> ScreenKeyPress {
        let parts = spec
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { throw ParseError.empty }

        var flags: CGEventFlags = []
        var keyName: String?
        for part in parts {
            switch part {
            case "command", "cmd", "⌘":
                flags.insert(.maskCommand)
            case "shift", "⇧":
                flags.insert(.maskShift)
            case "option", "alt", "⌥":
                flags.insert(.maskAlternate)
            case "control", "ctrl", "⌃":
                flags.insert(.maskControl)
            case "fn", "function":
                flags.insert(.maskSecondaryFn)
            default:
                if keyName != nil { throw ParseError.unknownKey(part) }
                keyName = part
            }
        }

        guard let keyName else { throw ParseError.empty }
        guard let keyCode = keyCode(for: keyName) else { throw ParseError.unknownKey(keyName) }
        return ScreenKeyPress(keyCode: keyCode, flags: flags)
    }

    static func keyCode(for name: String) -> UInt16? {
        switch name {
        case "return", "enter":
            return UInt16(kVK_Return)
        case "esc", "escape":
            return UInt16(kVK_Escape)
        case "tab":
            return UInt16(kVK_Tab)
        case "space", "spacebar":
            return UInt16(kVK_Space)
        case "delete", "backspace":
            return UInt16(kVK_Delete)
        case "forwarddelete":
            return UInt16(kVK_ForwardDelete)
        case "up":
            return UInt16(kVK_UpArrow)
        case "down":
            return UInt16(kVK_DownArrow)
        case "left":
            return UInt16(kVK_LeftArrow)
        case "right":
            return UInt16(kVK_RightArrow)
        case "home":
            return UInt16(kVK_Home)
        case "end":
            return UInt16(kVK_End)
        case "pageup":
            return UInt16(kVK_PageUp)
        case "pagedown":
            return UInt16(kVK_PageDown)
        default:
            if name.count == 1, let scalar = name.unicodeScalars.first {
                return letterOrDigitKeyCode(scalar)
            }
            return nil
        }
    }

    private static func letterOrDigitKeyCode(_ scalar: UnicodeScalar) -> UInt16? {
        switch scalar {
        case "a": return UInt16(kVK_ANSI_A)
        case "b": return UInt16(kVK_ANSI_B)
        case "c": return UInt16(kVK_ANSI_C)
        case "d": return UInt16(kVK_ANSI_D)
        case "e": return UInt16(kVK_ANSI_E)
        case "f": return UInt16(kVK_ANSI_F)
        case "g": return UInt16(kVK_ANSI_G)
        case "h": return UInt16(kVK_ANSI_H)
        case "i": return UInt16(kVK_ANSI_I)
        case "j": return UInt16(kVK_ANSI_J)
        case "k": return UInt16(kVK_ANSI_K)
        case "l": return UInt16(kVK_ANSI_L)
        case "m": return UInt16(kVK_ANSI_M)
        case "n": return UInt16(kVK_ANSI_N)
        case "o": return UInt16(kVK_ANSI_O)
        case "p": return UInt16(kVK_ANSI_P)
        case "q": return UInt16(kVK_ANSI_Q)
        case "r": return UInt16(kVK_ANSI_R)
        case "s": return UInt16(kVK_ANSI_S)
        case "t": return UInt16(kVK_ANSI_T)
        case "u": return UInt16(kVK_ANSI_U)
        case "v": return UInt16(kVK_ANSI_V)
        case "w": return UInt16(kVK_ANSI_W)
        case "x": return UInt16(kVK_ANSI_X)
        case "y": return UInt16(kVK_ANSI_Y)
        case "z": return UInt16(kVK_ANSI_Z)
        case "0": return UInt16(kVK_ANSI_0)
        case "1": return UInt16(kVK_ANSI_1)
        case "2": return UInt16(kVK_ANSI_2)
        case "3": return UInt16(kVK_ANSI_3)
        case "4": return UInt16(kVK_ANSI_4)
        case "5": return UInt16(kVK_ANSI_5)
        case "6": return UInt16(kVK_ANSI_6)
        case "7": return UInt16(kVK_ANSI_7)
        case "8": return UInt16(kVK_ANSI_8)
        case "9": return UInt16(kVK_ANSI_9)
        default: return nil
        }
    }
}
