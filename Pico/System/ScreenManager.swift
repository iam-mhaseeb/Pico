import AppKit
import CoreGraphics

enum ScreenManager {
    static var primaryScreen: NSScreen {
        NSScreen.screens.first ?? NSScreen.main!
    }

    /// Global desktop height used to convert CGWindow (top-left) → Cocoa (bottom-left).
    private static var globalDesktopHeight: CGFloat {
        let union = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        return union.maxY
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

    static func screen(forDisplayID displayID: UInt32) -> NSScreen? {
        NSScreen.screens.first { screen in
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return screenNumber?.uint32Value == displayID
        }
    }

    static func displayID(for screen: NSScreen) -> UInt32 {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return screenNumber?.uint32Value ?? 0
    }

    static func defaultPetOrigin(on screen: NSScreen) -> CGPoint {
        let visible = screen.visibleFrame
        let size = PicoTheme.petSize
        return CGPoint(
            x: visible.maxX - size - PicoTheme.screenMargin,
            y: visible.minY + PicoTheme.screenMargin
        )
    }

    static func clampOrigin(_ origin: CGPoint, size: CGSize, on screen: NSScreen) -> CGPoint {
        let visible = screen.visibleFrame
        return CGPoint(
            x: min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4),
            y: min(max(origin.y, visible.minY + 4), visible.maxY - size.height - 4)
        )
    }
}
