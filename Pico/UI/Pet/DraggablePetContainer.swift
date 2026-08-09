import AppKit
import SwiftUI

/// Hosts the pet SwiftUI view and moves the panel using screen mouse deltas.
/// SwiftUI DragGesture jitters because the view moves under the cursor mid-gesture.
final class DraggablePetContainer: NSView {
    var onClick: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var menuBuilder: (() -> NSMenu)?

    private var hostingView: NSHostingView<AnyView>?
    private var mouseDownScreenPoint: CGPoint?
    private var windowOriginAtMouseDown: CGPoint?
    private var isDragging = false
    private let dragThreshold: CGFloat = 3

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
        appearance = NSAppearance(named: .aqua)
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
        // Container owns hit-testing so AppKit drag stays smooth.
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

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        mouseDownScreenPoint = NSEvent.mouseLocation
        windowOriginAtMouseDown = window.frame.origin
        isDragging = false
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

        if isDragging {
            isDragging = false
            onDragEnded?()
            return
        }

        if event.clickCount == 1 {
            onClick?()
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuBuilder?()
    }

    private func clampedOrigin(_ origin: CGPoint, for window: NSWindow) -> CGPoint {
        let size = window.frame.size
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return origin }

        let proposed = NSRect(origin: origin, size: size)
        let containing = screens.first(where: { $0.frame.intersects(proposed) }) ?? screens[0]
        let visible = containing.visibleFrame
        let margin: CGFloat = 4
        return CGPoint(
            x: min(
                max(origin.x, visible.minX + margin - size.width * 0.35),
                visible.maxX - size.width * 0.65
            ),
            y: min(
                max(origin.y, visible.minY + margin - size.height * 0.35),
                visible.maxY - size.height * 0.65
            )
        )
    }
}
