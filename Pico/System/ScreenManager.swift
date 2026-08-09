import AppKit
import CoreGraphics

enum ScreenManager {
    static var primaryScreen: NSScreen {
        NSScreen.screens.first ?? NSScreen.main!
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
                let bounds = CGRect(
                    x: boundsDict["X"] ?? 0,
                    y: boundsDict["Y"] ?? 0,
                    width: boundsDict["Width"] ?? 0,
                    height: boundsDict["Height"] ?? 0
                )
                if let screen = NSScreen.screens.first(where: { $0.frame.intersects(bounds) }) {
                    return screen
                }
            }
        }
        return NSScreen.main ?? primaryScreen
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
}
