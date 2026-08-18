import AppKit
@preconcurrency import ApplicationServices
import Foundation

struct AXElementMap {
    var elements: [Int: AXUIElement] = [:]

    subscript(id: Int) -> AXUIElement? {
        elements[id]
    }
}

/// AX role names as strings — some `kAX*Role` constants (notably `kAXLinkRole`) are not
/// exported to Swift on macOS.
enum AXRoleName {
    static let interactive: Set<String> = [
        "AXButton",
        "AXCheckBox",
        "AXRadioButton",
        "AXPopUpButton",
        "AXMenuButton",
        "AXTextField",
        "AXSecureTextField",
        "AXTextArea",
        "AXComboBox",
        "AXLink",
        "AXMenuItem",
        "AXTabGroup",
        "AXSlider",
        "AXIncrementor",
        "AXSearchField",
        "AXTab"
    ]

    static let readableText: Set<String> = [
        "AXStaticText",
        "AXHeading"
    ]

    static func isInteractive(_ role: String) -> Bool {
        interactive.contains(role)
    }

    static func isReadableText(_ role: String) -> Bool {
        readableText.contains(role)
    }
}

@MainActor
protocol AXSnapshotProviding: AnyObject {
    func snapshot(pid: pid_t, appName: String) -> (AccessibilitySnapshot, AXElementMap)
}

@MainActor
final class AccessibilityTreeSnapshotter: AXSnapshotProviding {
    var maxNodes = 100
    var maxDepth = 12

    func snapshot(pid: pid_t, appName: String) -> (AccessibilitySnapshot, AXElementMap) {
        let app = AXUIElementCreateApplication(pid)
        let window = focusedWindow(from: app)
        let windowTitle = stringAttribute(window, kAXTitleAttribute as String) ?? ""

        var map = AXElementMap()
        var nodes: [AXNode] = []
        var nextID = 1
        var visited = Set<UInt>()

        if let window {
            walk(
                window,
                depth: 0,
                nextID: &nextID,
                nodes: &nodes,
                map: &map,
                visited: &visited
            )
        }

        let snapshot = AccessibilitySnapshot(
            appName: appName,
            pid: pid,
            windowTitle: windowTitle,
            nodes: nodes
        )
        return (snapshot, map)
    }

    private func focusedWindow(from app: AXUIElement) -> AXUIElement? {
        if let focused = copyElement(app, kAXFocusedWindowAttribute as String) {
            return focused
        }
        if let windows = copyArray(app, kAXWindowsAttribute as String) {
            return windows.first
        }
        return nil
    }

    private func walk(
        _ element: AXUIElement,
        depth: Int,
        nextID: inout Int,
        nodes: inout [AXNode],
        map: inout AXElementMap,
        visited: inout Set<UInt>
    ) {
        guard depth <= maxDepth, nodes.count < maxNodes else { return }
        let token = UInt(CFHash(element))
        if visited.contains(token) { return }
        visited.insert(token)

        let role = stringAttribute(element, kAXRoleAttribute as String) ?? "unknown"
        let title = resolvedTitle(element)
        let secure = isSecure(element, role: role)
        let value = secure ? nil : stringAttribute(element, kAXValueAttribute as String)
        let enabled = boolAttribute(element, kAXEnabledAttribute as String) ?? true

        if shouldInclude(role: role, title: title, value: value) {
            let node = AXNode(
                id: nextID,
                role: shortRole(role),
                title: title,
                value: value,
                enabled: enabled,
                secure: secure
            )
            map.elements[nextID] = element
            nodes.append(node)
            nextID += 1
        }

        guard depth < maxDepth, nodes.count < maxNodes else { return }
        for child in copyArray(element, kAXChildrenAttribute as String) ?? [] {
            walk(
                child,
                depth: depth + 1,
                nextID: &nextID,
                nodes: &nodes,
                map: &map,
                visited: &visited
            )
            if nodes.count >= maxNodes { return }
        }
    }

    private func shouldInclude(role: String, title: String, value: String?) -> Bool {
        if AXRoleName.isInteractive(role) { return !title.isEmpty || (value?.isEmpty == false) }
        if AXRoleName.isReadableText(role) {
            return !title.isEmpty
        }
        return false
    }

    private func resolvedTitle(_ element: AXUIElement) -> String {
        let keys = [
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXHelpAttribute as String,
            kAXValueAttribute as String
        ]
        for key in keys {
            if let value = stringAttribute(element, key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return String(trimmed.prefix(80)) }
            }
        }
        return ""
    }

    private func isSecure(_ element: AXUIElement, role: String) -> Bool {
        if role == "AXSecureTextField" { return true }
        if let subrole = stringAttribute(element, kAXSubroleAttribute as String),
           subrole == "AXSecureTextField" {
            return true
        }
        return false
    }

    private func shortRole(_ role: String) -> String {
        if role.hasPrefix("AX"), role.count > 2 {
            let raw = role.dropFirst(2)
            return raw.prefix(1).lowercased() + raw.dropFirst()
        }
        return role
    }

    private func stringAttribute(_ element: AXUIElement?, _ name: String) -> String? {
        guard let element else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value else { return nil }
        return value as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ name: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value else { return nil }
        if let number = value as? NSNumber { return number.boolValue }
        return value as? Bool
    }

    private func copyElement(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value else { return nil }
        return (value as! AXUIElement)
    }

    private func copyArray(_ element: AXUIElement, _ name: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value else { return nil }
        if let elements = value as? [AXUIElement] {
            return elements
        }
        guard let array = value as? NSArray else { return nil }
        var elements: [AXUIElement] = []
        for item in array {
            elements.append(item as! AXUIElement)
        }
        return elements
    }
}
