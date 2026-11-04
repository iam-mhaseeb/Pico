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
            "Text Actions",
            "About Pico",
            "Settings…",
            pauseTitle(isPaused: isPaused),
            "Quit Pico"
        ]
    }
}
