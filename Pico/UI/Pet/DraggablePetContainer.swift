import AppKit
import SwiftUI

/// Hosts the pet SwiftUI view and moves the panel using screen mouse deltas.
final class DraggablePetContainer: NSView {
    var onAsk: (() -> Void)?
    var onPet: (() -> Void)?
    var onFeed: (() -> Void)?
    var onShoo: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var menuBuilder: (() -> NSMenu)?

    private var hostingView: NSHostingView<AnyView>?
    private var mouseDownScreenPoint: CGPoint?
    private var windowOriginAtMouseDown: CGPoint?
    private var isDragging = false
    private var isHovering = false
    private var singleClickWorkItem: DispatchWorkItem?
    private var longPressWorkItem: DispatchWorkItem?
    private var didLongPress = false
    private let dragThreshold: CGFloat = 3
    private let longPressDelay: TimeInterval = 0.45

    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureClearBackground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureClearBackground()
    }

    private func configureClearBackground() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
        super.updateTrackingAreas()
    }

    func setRootView<Content: View>(_ view: Content) {
        let clearRoot = AnyView(view.background(Color.clear))
        if let hostingView {
            hostingView.rootView = clearRoot
            return
        }
        let hosting = NSHostingView(rootView: clearRoot)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(hosting, positioned: .below, relativeTo: nil)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        hostingView = hosting
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func accessibilityLabel() -> String? { "Pico" }

    override func accessibilityRole() -> NSAccessibility.Role? { .button }

    override func accessibilityHelp() -> String? {
        "Click to pet. Double-click to feed. Right-click to shoo. Press and hold to ask Pico. Drag to move. Control-click for the menu."
    }

    override func accessibilityPerformPress() -> Bool {
        onPet?()
        return true
    }

    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        [
            NSAccessibilityCustomAction(name: "Pet Pico") { [weak self] in
                self?.onPet?()
                return true
            },
            NSAccessibilityCustomAction(name: "Feed Pico") { [weak self] in
                self?.onFeed?()
                return true
            },
            NSAccessibilityCustomAction(name: "Shoo Pico") { [weak self] in
                self?.onShoo?()
                return true
            },
            NSAccessibilityCustomAction(name: "Ask Pico") { [weak self] in
                self?.onAsk?()
                return true
            }
        ]
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isDragging else { return }
        isHovering = true
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        onHoverChanged?(false)
    }

    var isCurrentlyDragging: Bool { isDragging }

    override func mouseDown(with event: NSEvent) {
        guard window != nil else { return }
        if event.modifierFlags.contains(.control) {
            cancelPendingClicks()
            if let menu = menuBuilder?() {
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            }
            return
        }
        mouseDownScreenPoint = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin
        isDragging = false
        didLongPress = false
        scheduleLongPress()
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let window,
            let mouseDownScreenPoint,
            let windowOriginAtMouseDown
        else { return }

        let current = NSEvent.mouseLocation
        let deltaX = current.x - mouseDownScreenPoint.x
        let deltaY = current.y - mouseDownScreenPoint.y

        if !isDragging {
            guard hypot(deltaX, deltaY) >= dragThreshold else { return }
            isDragging = true
            cancelPendingClicks()
            if isHovering {
                isHovering = false
                onHoverChanged?(false)
            }
        }

        let newOrigin = clampedOrigin(
            CGPoint(
                x: windowOriginAtMouseDown.x + deltaX,
                y: windowOriginAtMouseDown.y + deltaY
            ),
            for: window
        )
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownScreenPoint = nil
            windowOriginAtMouseDown = nil
        }

        cancelLongPress()

        if isDragging {
            isDragging = false
            onDragEnded?()
            return
        }

        if didLongPress {
            return
        }

        let resolution = PetClickResolver.resolve(
            dragged: false,
            longPress: false,
            clickCount: event.clickCount,
            rightClick: false,
            controlClick: false
        )
        switch resolution {
        case .feed:
            cancelSingleClick()
            onFeed?()
        case .pet:
            cancelSingleClick()
            let work = DispatchWorkItem { [weak self] in
                self?.onPet?()
            }
            singleClickWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + NSEvent.doubleClickInterval,
                execute: work
            )
        default:
            break
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        cancelPendingClicks()
        if event.modifierFlags.contains(.control) {
            if let menu = menuBuilder?() {
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            }
            return
        }
        onShoo?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuBuilder?()
    }

    private func cancelSingleClick() {
        singleClickWorkItem?.cancel()
        singleClickWorkItem = nil
    }

    private func cancelLongPress() {
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
    }

    private func cancelPendingClicks() {
        cancelSingleClick()
        cancelLongPress()
    }

    private func scheduleLongPress() {
        cancelLongPress()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isDragging else { return }
            self.didLongPress = true
            self.cancelSingleClick()
            self.onAsk?()
        }
        longPressWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressDelay, execute: work)
    }

    func clampedOrigin(_ origin: CGPoint, for window: NSWindow) -> CGPoint {
        let size = window.frame.size
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return origin }

        let proposed = NSRect(origin: origin, size: size)
        let containing = screens.first(where: { $0.frame.intersects(proposed) }) ?? screens[0]
        return ScreenManager.clampOrigin(origin, size: size, on: containing)
    }
}
