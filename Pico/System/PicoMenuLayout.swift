import Foundation

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

    static func petMenuTitles(isPaused: Bool) -> [String] {
        [
            "Ask Pico",
            "Text Actions",
            "History",
            "Pet Pico",
            "Feed Pico",
            "Shoo Pico",
            "Settings",
            pauseTitle(isPaused: isPaused),
            "Quit Pico"
        ]
    }
}
