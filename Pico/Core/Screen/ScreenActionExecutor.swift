import AppKit
@preconcurrency import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

@MainActor
protocol ScreenActing: AnyObject {
    func press(element: AXUIElement) -> Bool
    func focus(element: AXUIElement) -> Bool
    func isSecure(element: AXUIElement) -> Bool
    func typeText(_ text: String)
    func pressKey(_ spec: String) throws
    func clickQuartz(point: CGPoint)
    /// True when the system-wide focused element is a password field.
    func focusedElementIsSecure() -> Bool
}

extension ScreenActing {
    func focusedElementIsSecure() -> Bool { false }
}

@MainActor
final class ScreenActionExecutor: ScreenActing {
    static let maxTypeCharacters = 2_000

    func press(element: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        return result == .success
    }

    func focus(element: AXUIElement) -> Bool {
        let focused = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        if focused == .success { return true }
        return AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
    }

    func isSecure(element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let role,
           (role as? String) == "AXSecureTextField" {
            return true
        }
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           let subrole,
           let text = subrole as? String,
           text == "AXSecureTextField" {
            return true
        }
        return false
    }

    func focusedElementIsSecure() -> Bool {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return false }
        return isSecure(element: focused as! AXUIElement)
    }

    func typeText(_ text: String) {
        let clipped = String(text.prefix(Self.maxTypeCharacters))
        let source = CGEventSource(stateID: .hidSystemState)
        // One key event per grapheme so emoji and combined characters stay intact.
        for character in clipped {
            if character == "\n" || character == "\r\n" {
                postKey(code: UInt16(kVK_Return), flags: [], source: source)
            } else if character == "\t" {
                postKey(code: UInt16(kVK_Tab), flags: [], source: source)
            } else {
                var chars = Array(String(character).utf16)
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
                down?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                up?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                down?.post(tap: .cghidEventTap)
                up?.post(tap: .cghidEventTap)
            }
            // Brief gap so busy apps don't drop characters.
            usleep(1_500)
        }
    }

    func pressKey(_ spec: String) throws
    func clickQuartz(point: CGPoint)
    /// True when the system-wide focused element is a password field.
    func focusedElementIsSecure() -> Bool
}

extension ScreenActing {
    func focusedElementIsSecure() -> Bool { false }
}

@MainActor
final class ScreenActionExecutor: ScreenActing {
    static let maxTypeCharacters = 2_000

    func press(element: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        return result == .success
    }

    func focus(element: AXUIElement) -> Bool {
        let focused = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        if focused == .success { return true }
        return AXUIElementPerformAction(element, kAXRaiseAction as CFString) == .success
    }

    func isSecure(element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let role,
           (role as? String) == "AXSecureTextField" {
            return true
        }
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           let subrole,
           let text = subrole as? String,
           text == "AXSecureTextField" {
            return true
        }
        return false
    }

    func typeText(_ text: String) {
        let clipped = String(text.prefix(Self.maxTypeCharacters))
        let source = CGEventSource(stateID: .hidSystemState)
        for scalar in clipped.unicodeScalars {
            if scalar == "\n" {
                postKey(code: UInt16(kVK_Return), flags: [], source: source)
                continue
            }
            if scalar == "\t" {
                postKey(code: UInt16(kVK_Tab), flags: [], source: source)
                continue
            }
            var chars = Array(String(scalar).utf16)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            down?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            up?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    func pressKey(_ spec: String) throws {
        let parsed = try ScreenKeyPressParser.parse(spec)
        let source = CGEventSource(stateID: .hidSystemState)
        postKey(code: parsed.keyCode, flags: parsed.flags, source: source)
    }

    func clickQuartz(point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        let up = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func postKey(code: UInt16, flags: CGEventFlags, source: CGEventSource?) {
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
