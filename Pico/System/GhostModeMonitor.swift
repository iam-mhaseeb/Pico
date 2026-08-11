import AppKit
@preconcurrency import ApplicationServices
import Foundation

/// Fades Pico while the user is focused in an editable field (and briefly after typing there).
@MainActor
final class GhostModeMonitor {
    var onGhostActiveChanged: ((Bool) -> Void)?

    private(set) var isGhostActive = false
    private var enabled = true
    private var lastEditableActivityAt: Date?
    private var pollTimer: Timer?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    /// How long after leaving an editable field before restoring full opacity.
    var idleRestoreDelay: TimeInterval = 1.6

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if !enabled {
            lastEditableActivityAt = nil
            updateGhostActive(false)
        } else {
            evaluate()
        }
    }

    func start() {
        stopMonitors()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.noteKeyIfEditing()
            }
            return event
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            Task { @MainActor in
                self?.noteKeyIfEditing()
            }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluate()
            }
        }
        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
        evaluate()
    }

    func stop() {
        stopMonitors()
        lastEditableActivityAt = nil
        updateGhostActive(false)
    }

    private func stopMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func noteKeyIfEditing() {
        guard enabled else { return }
        guard isFocusedOnEditableText() else { return }
        lastEditableActivityAt = Date()
        updateGhostActive(true)
    }

    private func evaluate() {
        guard enabled else {
            updateGhostActive(false)
            return
        }

        if isFocusedOnEditableText() {
            lastEditableActivityAt = Date()
            updateGhostActive(true)
            return
        }

        if let lastEditableActivityAt,
           Date().timeIntervalSince(lastEditableActivityAt) < idleRestoreDelay {
            updateGhostActive(true)
            return
        }

        updateGhostActive(false)
    }

    private func updateGhostActive(_ active: Bool) {
        guard active != isGhostActive else { return }
        isGhostActive = active
        onGhostActiveChanged?(active)
    }

    private func isFocusedOnEditableText() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        ) == .success,
              let focusedObject
        else { return false }

        let element = focusedObject as! AXUIElement

        if let editable = copyBool(element, kAXIsEditableAttribute as String), editable {
            return true
        }

        let role = copyString(element, kAXRoleAttribute as String) ?? ""
        let roles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField"
        ]
        if roles.contains(role) {
            return true
        }

        if let focused = copyBool(element, kAXFocusedAttribute as String), focused,
           copyString(element, kAXValueAttribute as String) != nil,
           role.contains("Text") || role.contains("Editor") {
            return true
        }

        return false
    }

    private func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value
        else { return nil }
        return value as? String
    }

    private func copyBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value
        else { return nil }
        return (value as? NSNumber)?.boolValue
    }
}
