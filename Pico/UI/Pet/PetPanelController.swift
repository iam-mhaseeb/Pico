import AppKit
import ObjectiveC
import QuartzCore
import SwiftUI

@MainActor
final class PetPanelController {
    private static var menuTargetAssociationKey: UInt8 = 0

    /// Vertical space reserved for a speech bubble above/below the pet face.
    static let bubbleSlotHeight: CGFloat = 34

    private var panel: FloatingPanel?
    private var container: DraggablePetContainer?
    private weak var coordinator: AppCoordinator?
    private let speech = PetSpeechPresenter()
    private var didGreetThisSession = false
    private var bubbleBelow = false
    private var isHovering = false
    private var hoverSquash: CGFloat = 1

    var frame: NSRect? {
        panel?.frame
    }

    /// Frame of the pet face itself (excludes bubble slot).
    var petFaceFrame: NSRect? {
        guard let panel else { return nil }
        let width = PicoTheme.petSize
        let height = PicoTheme.petSize
        let x = panel.frame.midX - width / 2
        let y: CGFloat
        if speech.text != nil, bubbleBelow {
            y = panel.frame.maxY - height
        } else {
            y = panel.frame.minY
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }

    func attach(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        speech.onChange = { [weak self] in
            self?.handleSpeechChange()
        }
    }

    func show() {
        guard let coordinator else { return }
        if panel == nil {
            let origin = restoredOrigin()
            let size = NSSize(width: PicoTheme.petSize, height: PicoTheme.petSize)
            let panel = FloatingPanel(
                contentRect: NSRect(origin: origin, size: size),
                styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]
            )
            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            panel.level = .floating
            panel.hasShadow = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            // Never become key — speech bubbles must not steal focus.
            panel.becomesKeyOnlyIfNeeded = true

            let container = DraggablePetContainer(frame: NSRect(origin: .zero, size: size))
            container.autoresizingMask = [.width, .height]
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.clear.cgColor
            container.setRootView(makePetRoot(coordinator: coordinator))
            container.onPet = { [weak coordinator] in
                coordinator?.handlePetGesture()
            }
            container.onFeed = { [weak coordinator] in
                coordinator?.handleFeedGesture()
            }
            container.onShoo = { [weak coordinator] in
                coordinator?.handleShooGesture()
            }
            container.onDragEnded = { [weak self] in
                self?.finishDragWithSnap()
            }
            container.onHoverChanged = { [weak self] hovering in
                self?.setHovering(hovering)
            }
            container.menuBuilder = { [weak coordinator] in
                Self.makeContextMenu(coordinator: coordinator)
            }
            panel.contentView = container

            self.container = container
            self.panel = panel
        } else {
            refreshContent()
        }
        panel?.orderFrontRegardless()
        greetIfNeeded()
    }

    func hide() {
        speech.clear()
        panel?.orderOut(nil)
    }

    func refreshContent() {
        guard let coordinator, let container else { return }
        container.setRootView(makePetRoot(coordinator: coordinator))
    }

    func showSpeech(_ kind: PetSpeechKind) {
        updateBubbleFlipPreference()
        speech.show(kind)
    }

    func showSpeech(text: String) {
        updateBubbleFlipPreference()
        speech.show(text: text)
    }

    /// Hop to another spot on the same display (used by shoo gesture).
    func dashToRandomNearbySpot(animated: Bool) {
        guard let panel else { return }
        let screen = panel.screen ?? ScreenManager.primaryScreen
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let current = panel.frame.origin

        var candidate = current
        for _ in 0..<8 {
            let dx = CGFloat.random(in: 120...220) * (Bool.random() ? 1 : -1)
            let dy = CGFloat.random(in: 80...160) * (Bool.random() ? 1 : -1)
            let next = CGPoint(x: current.x + dx, y: current.y + dy)
            let clamped = container?.clampedOrigin(next, for: panel)
                ?? CGPoint(
                    x: min(max(next.x, visible.minX + 4), visible.maxX - size.width - 4),
                    y: min(max(next.y, visible.minY + 4), visible.maxY - size.height - 4)
                )
            if hypot(clamped.x - current.x, clamped.y - current.y) > 80 {
                candidate = clamped
                break
            }
            candidate = clamped
        }

        let apply = { [weak self] in
            panel.setFrameOrigin(candidate)
            self?.persistPosition()
        }

        if animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(
                    NSRect(origin: candidate, size: panel.frame.size),
                    display: true
                )
            } completionHandler: { [weak self] in
                self?.persistPosition()
            }
        } else {
            apply()
        }
    }

    func persistPosition() {
        guard let panel else { return }
        // Persist the pet-face origin (bottom-left of the face), not bubble chrome.
        let faceOrigin: CGPoint
        if speech.text != nil, !bubbleBelow {
            faceOrigin = panel.frame.origin
        } else if speech.text != nil, bubbleBelow {
            faceOrigin = CGPoint(
                x: panel.frame.origin.x,
                y: panel.frame.maxY - PicoTheme.petSize
            )
        } else {
            faceOrigin = panel.frame.origin
        }
        let screen = panel.screen ?? ScreenManager.primaryScreen
        UserDefaults.standard.set(faceOrigin.x, forKey: PreferenceKey.petOriginX)
        UserDefaults.standard.set(faceOrigin.y, forKey: PreferenceKey.petOriginY)
        UserDefaults.standard.set(
            Int(ScreenManager.displayID(for: screen)),
            forKey: PreferenceKey.petDisplayID
        )
    }

    private func finishDragWithSnap() {
        guard let panel else {
            persistPosition()
            return
        }
        let defaults = UserDefaults.standard
        let snapEnabled = defaults.object(forKey: PreferenceKey.petEdgeSnapEnabled) as? Bool ?? true
        let result = PetEdgeSnap.snapOrigin(
            for: panel.frame.size,
            from: panel.frame.origin,
            enabled: snapEnabled
        )

        let apply = { [weak self] in
            panel.setFrameOrigin(result.origin)
            self?.persistPosition()
        }

        guard result.origin != panel.frame.origin else {
            persistPosition()
            return
        }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            apply()
            return
        }

        // Springy settle without fighting Mission Control (no continuous physics loop).
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.42
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.17, 0.89, 0.32, 1.28)
            panel.animator().setFrame(
                NSRect(origin: result.origin, size: panel.frame.size),
                display: true
            )
        } completionHandler: { [weak self] in
            self?.persistPosition()
        }
    }

    func handleDisplayChange() {
        guard let panel else { return }
        let displayID = UInt32(UserDefaults.standard.integer(forKey: PreferenceKey.petDisplayID))
        if ScreenManager.screen(forDisplayID: displayID) == nil {
            let origin = ScreenManager.defaultPetOrigin(on: ScreenManager.primaryScreen)
            panel.setFrameOrigin(origin)
            persistPosition()
        }
    }

    private func makePetRoot(coordinator: AppCoordinator) -> some View {
        PetView(
            coordinator: coordinator,
            bubbleText: speech.text,
            bubbleBelow: bubbleBelow,
            hoverSquash: hoverSquash
        )
    }

    private func setHovering(_ hovering: Bool) {
        // Drag path clears hover before calling; ignore while dragging.
        if hovering, container?.isCurrentlyDragging == true {
            return
        }
        isHovering = hovering
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            // Opacity / static highlight only — no squash animation.
            hoverSquash = 1
            container?.alphaValue = hovering ? 0.92 : 1.0
        } else {
            container?.alphaValue = 1.0
            hoverSquash = hovering ? 1.08 : 1.0
        }
        refreshContent()
    }

    private func handleSpeechChange() {
        relayoutForSpeech()
        refreshContent()
        // Keep non-activating: never promote to key window.
        panel?.orderFrontRegardless()
    }

    private func greetIfNeeded() {
        guard !didGreetThisSession else { return }
        didGreetThisSession = true
        // Slight delay so the panel is on-screen first.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard self.panel?.isVisible == true else { return }
            self.showSpeech(.greeting)
        }
    }

    private func updateBubbleFlipPreference() {
        guard let panel else {
            bubbleBelow = false
            return
        }
        let screen = panel.screen ?? ScreenManager.primaryScreen
        let faceTop = panel.frame.minY + PicoTheme.petSize
        let spaceAbove = screen.visibleFrame.maxY - faceTop
        bubbleBelow = spaceAbove < Self.bubbleSlotHeight + 8
    }

    private func relayoutForSpeech() {
        guard let panel else { return }
        let faceOrigin: CGPoint = {
            if speech.text != nil || panel.frame.height > PicoTheme.petSize + 1 {
                // Derive face origin from current layout.
                if panel.frame.height > PicoTheme.petSize + 1 {
                    if bubbleBelow {
                        return CGPoint(x: panel.frame.origin.x, y: panel.frame.maxY - PicoTheme.petSize)
                    }
                    return panel.frame.origin
                }
            }
            return panel.frame.origin
        }()

        let hasBubble = speech.text != nil
        let width = max(PicoTheme.petSize, PicoTheme.petBubbleSize)
        let height = PicoTheme.petSize + (hasBubble ? Self.bubbleSlotHeight : 0)
        let origin: CGPoint
        if hasBubble, bubbleBelow {
            origin = CGPoint(x: faceOrigin.x - (width - PicoTheme.petSize) / 2, y: faceOrigin.y - Self.bubbleSlotHeight)
        } else if hasBubble {
            origin = CGPoint(x: faceOrigin.x - (width - PicoTheme.petSize) / 2, y: faceOrigin.y)
        } else {
            origin = faceOrigin
        }
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        container?.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
    }

    private func restoredOrigin() -> CGPoint {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PreferenceKey.petOriginX) != nil,
           defaults.object(forKey: PreferenceKey.petOriginY) != nil {
            let displayID = UInt32(defaults.integer(forKey: PreferenceKey.petDisplayID))
            if ScreenManager.screen(forDisplayID: displayID) != nil || displayID == 0 {
                return CGPoint(
                    x: defaults.double(forKey: PreferenceKey.petOriginX),
                    y: defaults.double(forKey: PreferenceKey.petOriginY)
                )
            }
        }
        return ScreenManager.defaultPetOrigin(on: ScreenManager.primaryScreen)
    }

    private static func makeContextMenu(coordinator: AppCoordinator?) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(Self.item("Ask Pico") { coordinator?.showAssistant() })
        menu.addItem(Self.item("History") { coordinator?.showHistory() })
        menu.addItem(Self.item("Settings") { coordinator?.showSettings() })
        menu.addItem(.separator())
        let pauseTitle = (coordinator?.isPaused == true) ? "Resume Pico" : "Pause Pico"
        menu.addItem(Self.item(pauseTitle) { coordinator?.togglePause() })
        menu.addItem(Self.item("Quit Pico") { coordinator?.quit() })
        return menu
    }

    private static func item(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(PetMenuTarget.performAction(_:)), keyEquivalent: "")
        let target = PetMenuTarget(action: action)
        item.target = target
        objc_setAssociatedObject(
            item,
            &menuTargetAssociationKey,
            target,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return item
    }
}

private final class PetMenuTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction(_ sender: Any?) {
        action()
    }
}
