import AppKit
@preconcurrency import ApplicationServices
import Foundation

@MainActor
final class AccessibilityManager {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestTrustPromptIfNeeded() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func selectedText() -> String? {
        guard isTrusted else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )
        guard focusResult == .success, let focused = focusedObject else { return nil }
        let element = focused as! AXUIElement

        var selectedObject: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedObject
        )
        guard selectedResult == .success, let selectedObject else { return nil }
        let text = selectedObject as? String
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? text : nil
    }

    func selectedTextRect() -> CGRect? {
        guard isTrusted else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        ) == .success,
              let focused = focusedObject
        else { return nil }
        let element = focused as! AXUIElement

        var rangeObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeObject
        ) == .success,
              let rangeObject
        else { return nil }

        var boundsObject: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeObject,
            &boundsObject
        )
        guard boundsResult == .success, let boundsObject else { return nil }

        var rect = CGRect.zero
        if AXValueGetValue(boundsObject as! AXValue, .cgRect, &rect) {
            return convertAXRectToCocoa(rect)
        }
        return nil
    }

    func setSelectedText(_ text: String) -> Bool {
        guard isTrusted else { return false }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        ) == .success,
              let focused = focusedObject
        else { return false }
        let element = focused as! AXUIElement
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }

    func openSystemSettings() {
        PermissionOpener.requestAccessibilityAccessAndOpenSettings()
    }

    private func convertAXRectToCocoa(_ axRect: CGRect) -> CGRect {
        guard let screen = NSScreen.screens.first else { return axRect }
        let screenHeight = screen.frame.maxY
        return CGRect(
            x: axRect.origin.x,
            y: screenHeight - axRect.origin.y - axRect.height,
            width: axRect.width,
            height: axRect.height
        )
    }
}
