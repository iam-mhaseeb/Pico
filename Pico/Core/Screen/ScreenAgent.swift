import AppKit
@preconcurrency import ApplicationServices
import Foundation

/// Coordinates screen looking and UI actions. Tools and Ask Pico share one instance.
@MainActor
@Observable
final class ScreenAgent {
    static let maxActionsPerTurn = 8

    var statusText: String?
    var permissionNeeded = false
    var accessibilityNeeded = false
    var isActing = false
    /// Once the user asks for screen help in a conversation, follow-ups can keep using tools.
    var sessionEnabled = false
    /// True for the current Ask turn (prompt intent, toggle, or an already-enabled session).
    private(set) var turnEnabled = false

    var hideChrome: (() async -> Void)?
    var restoreChrome: (() async -> Void)?

    private let capturer: any ScreenCapturing
    private let ocr: any ScreenOCRProviding
    private let ax: any AXSnapshotProviding
    private let actions: any ScreenActing
    private let permission: any ScreenPermissionChecking
    private let accessibilityTrusted: () -> Bool

    private var targetPID: pid_t?
    private var targetName: String?
    private var lastSnapshot: AccessibilitySnapshot?
    private var lastElements = AXElementMap()
    private var lastDisplayBounds = CGRect.zero
    private var lastDescription: String?
    private var actionsThisTurn = 0
    private let picoPID = ProcessInfo.processInfo.processIdentifier
    private let picoBundleID = Bundle.main.bundleIdentifier ?? "com.iamhaseeb.Pico"

    init(
        capturer: any ScreenCapturing = ScreenCaptureKitCapturer(),
        ocr: any ScreenOCRProviding = VisionScreenOCR(),
        ax: any AXSnapshotProviding = AccessibilityTreeSnapshotter(),
        actions: any ScreenActing = ScreenActionExecutor(),
        permission: any ScreenPermissionChecking = SystemScreenPermission(),
        accessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() }
    ) {
        self.capturer = capturer
        self.ocr = ocr
        self.ax = ax
        self.actions = actions
        self.permission = permission
        self.accessibilityTrusted = accessibilityTrusted
    }

    func rememberTargetApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != picoPID
        else { return }
        targetPID = app.processIdentifier
        targetName = app.localizedName
    }

    func beginTurn(enabled: Bool) {
        turnEnabled = enabled
        if enabled { sessionEnabled = true }
        actionsThisTurn = 0
        permissionNeeded = false
        accessibilityNeeded = false
        lastDescription = nil
        if !enabled {
            statusText = nil
            isActing = false
        }
    }

    func endTurn() {
        isActing = false
        if permissionNeeded == false, accessibilityNeeded == false {
            statusText = nil
        }
    }

    func resetSession() {
        sessionEnabled = false
        turnEnabled = false
        lastSnapshot = nil
        lastElements = AXElementMap()
        lastDescription = nil
        statusText = nil
        permissionNeeded = false
        accessibilityNeeded = false
        isActing = false
        actionsThisTurn = 0
    }

    func consumeTurnContext() -> String? {
        lastDescription
    }

    /// Capture OCR + Accessibility of the app the user was in before Ask Pico opened.
    @discardableResult
    func look(focus: String = "") async -> String {
        guard turnEnabled || sessionEnabled else {
            return "Screen help is off. The user didn’t ask to look at or control the screen. Answer from the conversation only."
        }
        turnEnabled = true
        isActing = true
        statusText = "Looking at \(resolvedTargetName())…"

        if !permission.hasScreenRecording {
            permissionNeeded = true
            let message = ScreenCaptureError.notPermitted.errorDescription
                ?? "Pico needs Screen Recording permission to see what’s on your screen."
            lastDescription = message
            statusText = message
            isActing = false
            return message
        }

        let target = resolveTarget()
        var axText = "(no accessibility tree)"
        if accessibilityTrusted() {
            if let pid = target.pid {
                let pair = ax.snapshot(pid: pid, appName: target.name)
                lastSnapshot = pair.0
                lastElements = pair.1
                axText = pair.0.description()
            }
        } else {
            accessibilityNeeded = true
            axText = "Accessibility permission is off — I can describe visible text but I can’t click UI elements yet."
        }

        var ocrText = ""
        do {
            let displayID = displayIDForTarget(pid: target.pid)
            let captured = try await capturer.captureDisplay(
                displayID: displayID,
                excludingBundleIDs: [picoBundleID]
            )
            lastDisplayBounds = captured.displayBounds
            let lines = ocr.lines(in: captured.image, maxLines: 80)
            ocrText = lines.map(\.formatted).joined(separator: "\n")
        } catch let error as ScreenCaptureError {
            if error == .notPermitted {
                permissionNeeded = true
            }
            ocrText = error.errorDescription ?? "Capture failed."
        } catch {
            ocrText = ScreenCaptureError.failed.errorDescription ?? "Capture failed."
        }

        if !focus.isEmpty {
            ocrText = "Focus hint from Pico: \(focus)\n" + ocrText
        }

        let description = ScreenDescription.compose(
            appName: target.name,
            ax: axText,
            ocr: ocrText
        )
        lastDescription = description
        statusText = "Looking at \(target.name)"
        isActing = false
        return description
    }

    func clickElement(target: String) async -> String {
        if let error = allowAction() { return error }

        if lastSnapshot == nil {
            _ = await look()
        }
        guard let snapshot = lastSnapshot else {
            return "I couldn’t find UI elements. Grant Accessibility and ask me to look again."
        }
        guard let node = snapshot.node(matching: target) else {
            let names = snapshot.nodes.prefix(8).map { "\($0.title) (#\($0.id))" }.joined(separator: ", ")
            return "I couldn’t find “\(target)”. Nearby: \(names.isEmpty ? "none" : names)."
        }
        guard !node.secure else {
            return "I won’t interact with a secure text field."
        }
        guard let element = lastElements[node.id] else {
            return "That element is no longer available. Ask me to look at the screen again."
        }

        await prepareForAction()
        let ok = actions.press(element: element)
        await finishAction()
        if ok {
            statusText = "Clicked \(node.title)"
            return "Clicked \(node.role) “\(node.title)” (#\(node.id))."
        }
        return "I found “\(node.title)” but couldn’t press it."
    }

    func typeText(_ text: String, field: String) async -> String {
        if let error = allowAction() { return error }
        let clipped = String(text.prefix(ScreenActionExecutor.maxTypeCharacters))
        guard !clipped.isEmpty else { return "Nothing to type." }

        if lastSnapshot == nil {
            _ = await look()
        }

        if !field.isEmpty, let snapshot = lastSnapshot, let node = snapshot.node(matching: field) {
            if node.secure {
                return "I won’t type into a secure text field."
            }
            if let element = lastElements[node.id] {
                if actions.isSecure(element: element) {
                    return "I won’t type into a secure text field."
                }
                await prepareForAction()
                _ = actions.focus(element: element)
                actions.typeText(clipped)
                await finishAction()
                statusText = "Typed into \(node.title)"
                return "Typed into “\(node.title)”."
            }
        }

        await prepareForAction()
        actions.typeText(clipped)
        await finishAction()
        statusText = "Typed text"
        return "Typed the requested text into the focused field."
    }

    func pressKey(_ spec: String) async -> String {
        if let error = allowAction() { return error }
        do {
            await prepareForAction()
            try actions.pressKey(spec)
            await finishAction()
            statusText = "Pressed \(spec)"
            return "Pressed \(spec)."
        } catch {
            isActing = false
            _ = await restoreChromeIfNeeded()
            return error.localizedDescription
        }
    }

    func clickAt(x: Double, y: Double) async -> String {
        if let error = allowAction() { return error }
        let bounds = lastDisplayBounds.isNull || lastDisplayBounds.isEmpty
            ? CGDisplayBounds(CGMainDisplayID())
            : lastDisplayBounds
        let point = ScreenCoordinates.quartzPoint(normalizedX: x, normalizedY: y, displayBounds: bounds)
        await prepareForAction()
        actions.clickQuartz(point: point)
        await finishAction()
        statusText = "Clicked on screen"
        return String(format: "Clicked at (%.2f, %.2f).", min(max(x, 0), 1), min(max(y, 0), 1))
    }

    /// Returns an error message when the action must not run; otherwise nil.
    private func allowAction() -> String? {
        guard turnEnabled || sessionEnabled else {
            return "Screen help is off. The user didn’t ask to control the screen."
        }
        turnEnabled = true
        if actionsThisTurn >= Self.maxActionsPerTurn {
            return "Action limit reached for this request."
        }
        if !accessibilityTrusted() {
            accessibilityNeeded = true
            return "Pico needs Accessibility permission to click, type, or press keys."
        }
        actionsThisTurn += 1
        return nil
    }

    private func prepareForAction() async {
        isActing = true
        guard hideChrome != nil else { return }
        await hideChrome?()
        await FrontmostAppHelper.activate(pid: resolveTarget().pid)
        try? await Task.sleep(nanoseconds: 80_000_000)
    }

    private func finishAction() async {
        if hideChrome != nil {
            try? await Task.sleep(nanoseconds: 120_000_000)
            await restoreChrome?()
        }
        isActing = false
    }

    private func restoreChromeIfNeeded() async {
        await restoreChrome?()
    }

    private func resolveTarget() -> (pid: pid_t?, name: String) {
        if let targetPID,
           let app = NSRunningApplication(processIdentifier: targetPID),
           !app.isTerminated {
            return (targetPID, targetName ?? app.localizedName ?? "App")
        }
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != picoPID {
            return (app.processIdentifier, app.localizedName ?? "App")
        }
        return (nil, "Mac")
    }

    private func resolvedTargetName() -> String {
        resolveTarget().name
    }

    private func displayIDForTarget(pid: pid_t?) -> CGDirectDisplayID {
        if let pid,
           let app = NSRunningApplication(processIdentifier: pid),
           let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
           ) as? [[String: Any]] {
            for info in windowList {
                guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                      ownerPID == pid,
                      let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat]
                else { continue }
                let cgBounds = CGRect(
                    x: boundsDict["X"] ?? 0,
                    y: boundsDict["Y"] ?? 0,
                    width: boundsDict["Width"] ?? 0,
                    height: boundsDict["Height"] ?? 0
                )
                let cocoa = ScreenManager.cocoaRect(fromCGWindowBounds: cgBounds)
                if let screen = NSScreen.screens.first(where: { $0.frame.intersects(cocoa) }) {
                    return ScreenManager.displayID(for: screen)
                }
            }
        }
        return ScreenManager.displayID(for: ScreenManager.screenContainingFrontmostApp())
    }
}

enum ScreenRuntime {
    @MainActor
    static var agent: ScreenAgent?
}
