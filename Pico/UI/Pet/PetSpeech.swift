import AppKit
import Foundation

enum PetSpeechKind: String, Sendable {
    case pet
    case feed
    case shoo
    case greeting
}

enum PetSpeechLines {
    private static let lines: [PetSpeechKind: [String]] = [
        .pet: ["Purr!", "Hehe!", "Nice!", "❤"],
        .feed: ["Yum!", "Nom nom!", "Thanks!", "Delicious!"],
        .shoo: ["Okay…", "Bye!", "Moving!", "Hmph."],
        .greeting: ["Hi!", "Hey there!", "I’m here!", "Hello!"]
    ]

    static func line(for kind: PetSpeechKind) -> String {
        let options = lines[kind] ?? ["…"]
        return options.randomElement() ?? options[0]
    }
}

@MainActor
final class PetSpeechPresenter {
    private(set) var text: String?
    private var dismissTask: Task<Void, Never>?
    var onChange: (() -> Void)?

    /// Default bubble lifetime in seconds.
    var ttl: TimeInterval = 2.0

    func show(_ kind: PetSpeechKind) {
        show(text: PetSpeechLines.line(for: kind))
    }

    func show(text: String) {
        dismissTask?.cancel()
        self.text = text
        onChange?()
        announce(text)

        let lifetime = ttl
        dismissTask = Task { [weak self] in
            let nanoseconds = UInt64(lifetime * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.text = nil
                self?.onChange?()
            }
        }
    }

    func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        if text != nil {
            text = nil
            onChange?()
        }
    }

    private func announce(_ text: String) {
        // Non-activating announcement so bubbles never steal keyboard focus.
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: "Pico says \(text)",
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }
}
