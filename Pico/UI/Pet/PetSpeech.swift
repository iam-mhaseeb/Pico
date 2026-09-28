import AppKit
import Foundation

enum PetSpeechKind: String, CaseIterable, Sendable {
    case pet
    case feed
    case shoo
    case greeting
    case success
    case error
    case sleep
    case wake
    case chase
    case morning
}

enum PetSpeechLines {
    static func line(for kind: PetSpeechKind, persona: PetPersona = .friendly) -> String {
        let options = lines(for: persona)[kind] ?? ["…"]
        return options.randomElement() ?? options[0]
    }

    static func lines(for persona: PetPersona) -> [PetSpeechKind: [String]] {
        switch persona {
        case .friendly:
            return [
                .pet: ["Purr!", "Hehe!", "Nice!"],
                .feed: ["Yum!", "Nom nom!", "Thanks!"],
                .shoo: ["Okay…", "Bye!", "Moving!"],
                .greeting: ["Hi!", "Hey there!", "I’m here!"],
                .success: ["Done!", "Nice!", "There we go!"],
                .error: ["Oops.", "Hmm.", "Let’s try again."],
                .sleep: ["Zzz…", "Night night."],
                .wake: ["Hm?", "I’m up!"],
                .chase: ["Ooh!", "Hi!"],
                .morning: ["Stretch!", "Morning!"]
            ]
        case .encouraging:
            return [
                .pet: ["You’ve got this!", "Yes!", "Proud of you!"],
                .feed: ["Fuel up!", "Nice treat!", "You earned it!"],
                .shoo: ["I’ll be nearby!", "Go get it!", "On my way!"],
                .greeting: ["Hey, superstar!", "Ready when you are!"],
                .success: ["Nailed it!", "Look at you!", "Great work!"],
                .error: ["All good.", "We can retry.", "Still with you."],
                .sleep: ["Rest well.", "I’ll be here."],
                .wake: ["Let’s go!", "Morning energy!"],
                .chase: ["Found you!", "Hey hey!"],
                .morning: ["Big stretch!", "New day!"]
            ]
        case .snarky:
            return [
                .pet: ["Oh, affection.", "Fine, I like it.", "Heh."],
                .feed: ["Finally.", "Acceptable.", "Nom. Obviously."],
                .shoo: ["Rude.", "I’m going.", "Wow. Okay."],
                .greeting: ["Oh. It’s you.", "I live here now."],
                .success: ["Told you.", "Easy.", "You’re welcome."],
                .error: ["Well.", "That tracks.", "Yikes."],
                .sleep: ["Don’t wait up.", "Zzz. Finally."],
                .wake: ["Ugh. Hi.", "Five more minutes."],
                .chase: ["Curious. Sue me.", "Boo."],
                .morning: ["Joints. Wow.", "I’m up. Happy?"]
            ]
        case .calm:
            return [
                .pet: ["Hello.", "That’s nice."],
                .feed: ["Thank you.", "Lovely."],
                .shoo: ["Alright.", "Moving."],
                .greeting: ["Hello.", "I’m here."],
                .success: ["Done.", "All set."],
                .error: ["Hmm.", "Okay."],
                .sleep: ["Resting.", "Quiet now."],
                .wake: ["Hello.", "Awake."],
                .chase: ["Hello.", "Hi."],
                .morning: ["Good morning.", "Stretch."]
            ]
        }
    }
}

@MainActor
final class PetSpeechPresenter {
    private(set) var text: String?
    private var dismissTask: Task<Void, Never>?
    var onChange: (() -> Void)?

    /// Default bubble lifetime in seconds.
    var ttl: TimeInterval = 2.0
    /// Avoid spamming VoiceOver when the user pets rapidly.
    private var lastAnnouncementAt: Date = .distantPast

    func show(_ kind: PetSpeechKind) {
        show(text: PetSpeechLines.line(for: kind))
    }

    func show(text: String) {
        dismissTask?.cancel()
        self.text = text
        onChange?()
        let now = Date()
        if now.timeIntervalSince(lastAnnouncementAt) > 1.5 {
            lastAnnouncementAt = now
            announce(text)
        }

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
