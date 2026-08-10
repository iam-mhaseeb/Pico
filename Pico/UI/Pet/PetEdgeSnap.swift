import AppKit
import Foundation

enum PetEdgeSnap {
    enum Edge: Equatable {
        case left, right, bottom, top
        case free
    }

    /// Nearest sensible snap target on the display containing `origin`.
    static func snapOrigin(
        for panelSize: CGSize,
        from origin: CGPoint,
        enabled: Bool
    ) -> (origin: CGPoint, edge: Edge, screen: NSScreen) {
        let proposed = NSRect(origin: origin, size: panelSize)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(proposed) })
            ?? NSScreen.main
            ?? ScreenManager.primaryScreen
        let visible = screen.visibleFrame
        let margin = PicoTheme.screenMargin

        let freeClamped = CGPoint(
            x: min(max(origin.x, visible.minX + 4), visible.maxX - panelSize.width - 4),
            y: min(max(origin.y, visible.minY + 4), visible.maxY - panelSize.height - 4)
        )

        guard enabled else {
            return (freeClamped, .free, screen)
        }

        let midX = freeClamped.x + panelSize.width / 2
        let midY = freeClamped.y + panelSize.height / 2
        let distLeft = midX - visible.minX
        let distRight = visible.maxX - midX
        let distBottom = midY - visible.minY
        let distTop = visible.maxY - midY

        let nearestHorizontal: (Edge, CGFloat) = distLeft <= distRight
            ? (.left, distLeft)
            : (.right, distRight)
        let nearestVertical: (Edge, CGFloat) = distBottom <= distTop
            ? (.bottom, distBottom)
            : (.top, distTop)

        // Prefer the closer axis; bias slightly to bottom/side dock like a desk buddy.
        let useHorizontal = nearestHorizontal.1 <= nearestVertical.1
        let edge = useHorizontal ? nearestHorizontal.0 : nearestVertical.0

        let snapped: CGPoint
        switch edge {
        case .left:
            snapped = CGPoint(x: visible.minX + margin, y: freeClamped.y)
        case .right:
            snapped = CGPoint(
                x: visible.maxX - panelSize.width - margin,
                y: freeClamped.y
            )
        case .bottom:
            snapped = CGPoint(x: freeClamped.x, y: visible.minY + margin)
        case .top:
            snapped = CGPoint(
                x: freeClamped.x,
                y: visible.maxY - panelSize.height - margin
            )
        case .free:
            snapped = freeClamped
        }
        return (snapped, edge, screen)
    }
}
