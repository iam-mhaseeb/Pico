import AppKit
import Foundation

enum PetEdgeSnap {
    enum Edge: Equatable {
        case left, right, bottom, top
        case free
    }

    /// Distance (pt) within which a drop will dock to an edge.
    static let snapProximity: CGFloat = 72

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

        let freeClamped = ScreenManager.clampOrigin(origin, size: panelSize, on: screen)

        guard enabled else {
            return (freeClamped, .free, screen)
        }

        let midX = freeClamped.x + panelSize.width / 2
        let midY = freeClamped.y + panelSize.height / 2
        let distLeft = midX - visible.minX
        let distRight = visible.maxX - midX
        let distBottom = midY - visible.minY
        let distTop = visible.maxY - midY

        let candidates: [(Edge, CGFloat)] = [
            (.left, distLeft),
            (.right, distRight),
            (.bottom, distBottom),
            (.top, distTop)
        ]
        guard let nearest = candidates.min(by: { $0.1 < $1.1 }),
              nearest.1 <= snapProximity
        else {
            return (freeClamped, .free, screen)
        }

        let snapped: CGPoint
        switch nearest.0 {
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
        return (snapped, nearest.0, screen)
    }
}
