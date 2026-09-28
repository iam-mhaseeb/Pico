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
    private var isGhosted = false
    private var ghostOpacity: CGFloat { PicoTheme.ghostOpacity }
    private var outfit: PetSeasonOutfit = .none
    private var showBow = false
    private var animationInterval: TimeInterval = 1.0 / 20.0
    private var pauseAnimation = false
    private var toastText: String?
    private var toyPanels: [UUID: FloatingPanel] = [:]
    var onDismissToast: (() -> Void)?
    var onGreeting: (() -> Void)?

    var isDragging: Bool { container?.isCurrentlyDragging ?? false }

    private var showsChrome: Bool { toastText != nil || speech.text != nil }

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
        if showsChrome, bubbleBelow {
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
            panel.allowsKeyFocus = false
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

            let container = DraggablePetContainer(frame: NSRect(origin: .zero, size: size))
            container.autoresizingMask = [.width, .height]
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.clear.cgColor
            container.setRootView(makePetRoot(coordinator: coordinator))
            container.onAsk = { [weak coordinator] in
                coordinator?.handleAskFromPet()
            }
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
                coordinator?.handlePetDragEnded()
            }
            container.onHoverChanged = { [weak self] hovering in
                self?.setHovering(hovering)
                if hovering {
                    coordinator?.handlePetHover()
                }
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
        if isGhosted {
            panel?.alphaValue = ghostOpacity
        } else {
            panel?.alphaValue = 1
        }
        greetIfNeeded()
    }

    func hide() {
        speech.clear()
        isGhosted = false
        panel?.alphaValue = 1
        panel?.orderOut(nil)
        hideToys()
    }

    func applyVisual(_ visual: PetVisualState) {
        outfit = visual.outfit
        showBow = visual.showBow
        animationInterval = visual.animationInterval
        pauseAnimation = visual.pauseAnimation
        let toastChanged = toastText != visual.toast
        toastText = visual.toast
        if toastChanged {
            updateBubbleFlipPreference()
            relayoutForSpeech()
        }
        refreshContent()
    }

    func movePetFace(to faceOrigin: CGPoint, animated: Bool) {
        guard let panel else { return }
        let origin = panelOrigin(forFaceOrigin: faceOrigin)
        let apply = {
            panel.setFrameOrigin(origin)
        }
        if animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.45
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.17, 0.89, 0.32, 1.28)
                panel.animator().setFrame(NSRect(origin: origin, size: panel.frame.size), display: true)
            } completionHandler: { [weak self] in
                self?.persistPosition()
            }
        } else {
            apply()
            persistPosition()
        }
    }

    func syncToys(_ toys: [PetToy]) {
        let live = Set(toys.map(\.id))
        for (id, toyPanel) in toyPanels where !live.contains(id) {
            toyPanel.orderOut(nil)
            toyPanels[id] = nil
        }
        for toy in toys {
            let toyPanel = toyPanels[toy.id] ?? makeToyPanel(for: toy)
            toyPanel.setFrameOrigin(toy.origin)
            if panel?.isVisible == true {
                toyPanel.orderFrontRegardless()
            }
            toyPanels[toy.id] = toyPanel
        }
    }

    private func hideToys() {
        for toyPanel in toyPanels.values {
            toyPanel.orderOut(nil)
        }
    }

    private func makeToyPanel(for toy: PetToy) -> FloatingPanel {
        let size = NSSize(width: PetToyDrop.toySize, height: PetToyDrop.toySize)
        let panel = FloatingPanel(
            contentRect: NSRect(origin: toy.origin, size: size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]
        )
        panel.isMovable = false
        panel.allowsKeyFocus = false
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.setSwiftUIContent(PetToyView(kind: toy.kind))
        return panel
    }

    private func panelOrigin(forFaceOrigin faceOrigin: CGPoint) -> CGPoint {
        let width = showsChrome ? max(PicoTheme.petSize, PicoTheme.petBubbleSize) : PicoTheme.petSize
        if showsChrome, bubbleBelow {
            return CGPoint(x: faceOrigin.x - (width - PicoTheme.petSize) / 2, y: faceOrigin.y - Self.bubbleSlotHeight)
        }
        if showsChrome {
            return CGPoint(x: faceOrigin.x - (width - PicoTheme.petSize) / 2, y: faceOrigin.y)
        }
        return faceOrigin
    }

    func setGhosted(_ ghosted: Bool, animated: Bool = true) {
        guard isGhosted != ghosted else { return }
        isGhosted = ghosted
        guard let panel, panel.isVisible else { return }

        // Hover reduce-motion uses container alpha; ghost uses panel alpha so they compose.
        let target: CGFloat = ghosted ? ghostOpacity : 1.0
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !animated || reduceMotion {
            panel.alphaValue = target
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = ghosted ? 0.22 : 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = target
        }
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
        if showsChrome, !bubbleBelow {
            faceOrigin = panel.frame.origin
        } else if showsChrome, bubbleBelow {
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
        // Snap using the pet-face footprint so speech-bubble chrome doesn't skew docking.
        let faceSize = CGSize(width: PicoTheme.petSize, height: PicoTheme.petSize)
        let faceOrigin: CGPoint = {
            if showsChrome, bubbleBelow {
                return CGPoint(x: panel.frame.origin.x, y: panel.frame.maxY - PicoTheme.petSize)
            }
            return panel.frame.origin
        }()
        let result = PetEdgeSnap.snapOrigin(
            for: faceSize,
            from: faceOrigin,
            enabled: snapEnabled
        )

        let targetOrigin: CGPoint = {
            if showsChrome, bubbleBelow {
                return CGPoint(x: result.origin.x, y: result.origin.y - Self.bubbleSlotHeight)
            }
            if showsChrome {
                let width = max(PicoTheme.petSize, PicoTheme.petBubbleSize)
                return CGPoint(x: result.origin.x - (width - PicoTheme.petSize) / 2, y: result.origin.y)
            }
            return result.origin
        }()

        let apply = { [weak self] in
            panel.setFrameOrigin(targetOrigin)
            self?.persistPosition()
        }

        guard targetOrigin != panel.frame.origin else {
            persistPosition()
            return
        }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            apply()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.42
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.17, 0.89, 0.32, 1.28)
            panel.animator().setFrame(
                NSRect(origin: targetOrigin, size: panel.frame.size),
                display: true
            )
        } completionHandler: { [weak self] in
            self?.persistPosition()
        }
    }

    func handleDisplayChange() {
        guard let panel else { return }
        let displayID = UInt32(UserDefaults.standard.integer(forKey: PreferenceKey.petDisplayID))
        let screen = ScreenManager.screen(forDisplayID: displayID) ?? ScreenManager.primaryScreen
        let clamped = ScreenManager.clampOrigin(
            panel.frame.origin,
            size: panel.frame.size,
            on: screen
        )
        if clamped != panel.frame.origin || ScreenManager.screen(forDisplayID: displayID) == nil {
            if ScreenManager.screen(forDisplayID: displayID) == nil {
                panel.setFrameOrigin(ScreenManager.defaultPetOrigin(on: ScreenManager.primaryScreen))
            } else {
                panel.setFrameOrigin(clamped)
            }
            persistPosition()
        }
    }

    private func makePetRoot(coordinator: AppCoordinator) -> some View {
        PetView(
            coordinator: coordinator,
            bubbleText: speech.text,
            bubbleBelow: bubbleBelow,
            hoverSquash: hoverSquash,
            outfit: outfit,
            showBow: showBow,
            animationInterval: animationInterval,
            pauseAnimation: pauseAnimation,
            toastText: toastText,
            onDismissToast: { [weak self] in self?.onDismissToast?() }
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
            self.onGreeting?()
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
            if showsChrome || panel.frame.height > PicoTheme.petSize + 1 {
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

        let hasBubble = showsChrome
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
        menu.autoenablesItems = false
        let paused = coordinator?.isPaused == true
        let ask = Self.item("Ask Pico") { coordinator?.showAssistant() }
        ask.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(ask)
        let text = Self.item("Text Actions") { coordinator?.showTextActions() }
        text.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(text)
        menu.addItem(Self.item("History") { coordinator?.showHistory() })
        menu.addItem(.separator())
        let pet = Self.item("Pet Pico") { coordinator?.handlePetGesture() }
        pet.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(pet)
        let feed = Self.item("Feed Pico") { coordinator?.handleFeedGesture() }
        feed.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(feed)
        let shoo = Self.item("Shoo Pico") { coordinator?.handleShooGesture() }
        shoo.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(shoo)
        menu.addItem(.separator())
        let toysEnabled = coordinator?.canDropToys == true
        for kind in PetToyKind.allCases {
            let item = Self.item("Drop \(kind.title)") { coordinator?.dropToy(kind) }
            item.isEnabled = toysEnabled
            menu.addItem(item)
        }
        let clear = Self.item("Clear toys") { coordinator?.clearToys() }
        clear.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(clear)
        menu.addItem(.separator())
        menu.addItem(Self.item("Settings") { coordinator?.showSettings() })
        let pauseTitle = PicoMenuLayout.pauseTitle(isPaused: paused)
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
