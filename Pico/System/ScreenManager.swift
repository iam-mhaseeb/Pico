import AppKit
import CoreGraphics

enum ScreenManager {
    static var primaryScreen: NSScreen {
        NSScreen.screens.first ?? NSScreen.main!
    }

    /// CGWindow and Accessibility coordinates have their origin at the top-left of the primary
    /// display, while Cocoa's origin is the bottom-left of the primary display. Flipping
    /// therefore uses the primary display's height, not the union of all screens.
    private static var globalDesktopHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func cocoaRect(fromCGWindowBounds cgBounds: CGRect) -> CGRect {
        let height = globalDesktopHeight
        return CGRect(
            x: cgBounds.origin.x,
            y: height - cgBounds.origin.y - cgBounds.height,
            width: cgBounds.width,
            height: cgBounds.height
        )
    }

    static func screenContainingFrontmostApp() -> NSScreen {
        if let app = NSWorkspace.shared.frontmostApplication,
           let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
           ) as? [[String: Any]] {
            let pid = app.processIdentifier
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
                let cocoaBounds = cocoaRect(fromCGWindowBounds: cgBounds)
                if let screen = NSScreen.screens.first(where: { $0.frame.intersects(cocoaBounds) }) {
                    return screen
                }
            }
        }
        return NSScreen.main ?? primaryScreen
    }

    static func screen(containing point: CGPoint) -> NSScreen {
        NSScreen.screens.first(where: { $0.frame.contains(point) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(CGRect(origin: point, size: CGSize(width: 1, height: 1))) })
            ?? primaryScreen
    }

    static func clampOrigin(_ origin: CGPoint, size: CGSize, on screen: NSScreen) -> CGPoint {
        let visible = screen.visibleFrame
        return CGPoint(
            x: min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4),
            y: min(max(origin.y, visible.minY + 4), visible.maxY - size.height - 4)
        )
    }
}
