import CoreGraphics

enum PicoMenuLayout {
    static func pauseTitle(isPaused: Bool) -> String {
        isPaused ? "Resume Pico" : "Pause Pico"
    }

    static func sessionActionsEnabled(isPaused: Bool) -> Bool {
        !isPaused
    }

    static func statusItemTitles(isPaused: Bool) -> [String] {
        [
            "Ask Pico",
            "Text Actions",
            "History",
            "Settings…",
            pauseTitle(isPaused: isPaused),
            "Quit Pico"
        ]
    }
}

enum MenuBarPanelPlacement {
    /// Opens a panel just under the menu-bar icon and keeps it on the visible screen.
    static func origin(anchor: CGRect, panelSize: CGSize, visibleFrame: CGRect, gap: CGFloat) -> CGPoint {
        let origin = CGPoint(
            x: anchor.midX - panelSize.width / 2,
            y: anchor.minY - panelSize.height - gap
        )
        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX + 4), visibleFrame.maxX - panelSize.width - 4),
            y: min(max(origin.y, visibleFrame.minY + 4), visibleFrame.maxY - panelSize.height - 4)
        )
    }
}
