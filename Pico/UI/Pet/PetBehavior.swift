import CoreGraphics
import Foundation

// MARK: - Gestures

/// Pointer resolution shared by the pet view and tests.
enum PetClickResolution: Equatable {
    case drag
    case pet
    case feed
    case ask
    case shoo
    case menu
}

enum PetClickResolver {
    /// Disambiguates play gestures from drag and Ask Pico.
    /// Click pets, double-click feeds, right-click shoos, press-and-hold asks, control-click opens the menu.
    static func resolve(
        dragged: Bool,
        longPress: Bool,
        clickCount: Int,
        rightClick: Bool,
        controlClick: Bool
    ) -> PetClickResolution {
        if controlClick { return .menu }
        if rightClick { return .shoo }
        if dragged { return .drag }
        if longPress { return .ask }
        if clickCount >= 2 { return .feed }
        return .pet
    }
}

enum PetInteraction: Equatable {
    case pet
    case feed
    case shoo
    case drag
    case ask
    case text
    case hover
    case toyCatch
}

// MARK: - Idle

enum PetHobby: String, CaseIterable, Codable, Sendable {
    case reading
    case stretching
    case humming
    case doodling
    case daydreaming

    var state: PetState {
        switch self {
        case .reading, .daydreaming: .curious
        case .stretching: .love
        case .humming: .celebrating
        case .doodling: .working
        }
    }

    var speech: String {
        switch self {
        case .reading: "Reading…"
        case .stretching: "Stretch!"
        case .humming: "Hmm ♪"
        case .doodling: "Doodling"
        case .daydreaming: "Daydream"
        }
    }
}

enum PetIdlePhase: Equatable {
    case awake
    case hobby(PetHobby)
    case sleeping
    case suppressed
}

enum PetIdle {
    static let hobbyAfter: TimeInterval = 45
    static let sleepAfter: TimeInterval = 300
    static let nightSleepAfter: TimeInterval = 20

    static func phase(idle: TimeInterval, suppressed: Bool, night: Bool) -> PetIdlePhase {
        if suppressed { return .suppressed }
        if night, idle >= nightSleepAfter { return .sleeping }
        if idle >= sleepAfter { return .sleeping }
        if idle >= hobbyAfter {
            let slot = Int(idle / hobbyAfter) % PetHobby.allCases.count
            return .hobby(PetHobby.allCases[slot])
        }
        return .awake
    }

    /// Hobbies are still awake enough to wander or peek. Sleep and hard suppression are not.
    static func allowsLocomotion(_ phase: PetIdlePhase) -> Bool {
        switch phase {
        case .awake, .hobby: true
        case .sleeping, .suppressed: false
        }
    }

    /// Trait nudges which hobby is shown first; the idle slot still rotates.
    static func hobby(idle: TimeInterval, bias: UsageTrait) -> PetHobby {
        let slot = Int(idle / hobbyAfter) % PetHobby.allCases.count
        switch bias {
        case .builder:
            return slot.isMultiple(of: 2) ? .doodling : PetHobby.allCases[slot]
        case .scholar:
            return slot.isMultiple(of: 2) ? .reading : PetHobby.allCases[slot]
        case .chatter, .balanced:
            return PetHobby.allCases[slot]
        }
    }
}

// MARK: - Focus blocks

struct FocusBlock: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var startMinutes: Int
    var endMinutes: Int
    var enabled: Bool

    init(id: UUID = UUID(), startMinutes: Int, endMinutes: Int, enabled: Bool = true) {
        self.id = id
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.enabled = enabled
    }
}

enum FocusSchedule {
    static func minutesSinceMidnight(_ date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// A window where start == end is empty. When start > end, the window crosses midnight.
    static func contains(minutes: Int, start: Int, end: Int) -> Bool {
        let minute = normalize(minutes)
        let startMinute = normalize(start)
        let endMinute = normalize(end)
        if startMinute == endMinute { return false }
        if startMinute < endMinute {
            return minute >= startMinute && minute < endMinute
        }
        return minute >= startMinute || minute < endMinute
    }

    static func isQuiet(at date: Date, blocks: [FocusBlock], calendar: Calendar = .current) -> Bool {
        let minutes = minutesSinceMidnight(date, calendar: calendar)
        return blocks.contains { block in
            block.enabled && contains(minutes: minutes, start: block.startMinutes, end: block.endMinutes)
        }
    }

    static func clockLabel(_ minutes: Int) -> String {
        let normalized = normalize(minutes)
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }

    private static func normalize(_ minutes: Int) -> Int {
        ((minutes % 1_440) + 1_440) % 1_440
    }
}

// MARK: - Context moods

enum PetContextMood: String, Codable, CaseIterable, Identifiable, Sendable {
    case idle
    case working
    case groove
    case social
    case curious

    var id: String { rawValue }

    var petState: PetState {
        switch self {
        case .idle: .idle
        case .working: .working
        case .groove: .celebrating
        case .social: .curious
        case .curious: .curious
        }
    }

    var title: String {
        switch self {
        case .idle: "Idle"
        case .working: "Working"
        case .groove: "Groove"
        case .social: "Social"
        case .curious: "Curious"
        }
    }
}

enum AppMoodCatalog {
    /// Bundle id → mood. Identity only; window contents are never read.
    static let builtIn: [String: PetContextMood] = [
        "com.apple.dt.Xcode": .working,
        "com.microsoft.VSCode": .working,
        "com.apple.Music": .groove,
        "com.apple.TV": .groove,
        "com.tinyspeck.slackmacgap": .social,
        "com.apple.MobileSMS": .social,
        "com.apple.mail": .social,
        "com.apple.Safari": .curious,
        "com.google.Chrome": .curious
    ]

    static func mood(bundleID: String?, overrides: [String: PetContextMood]) -> PetContextMood {
        guard let bundleID, !bundleID.isEmpty else { return .idle }
        if let override = overrides[bundleID] { return override }
        return builtIn[bundleID] ?? .idle
    }
}

struct MoodFlipLimiter {
    var minimumInterval: TimeInterval = 8

    func shouldApply(now: Date, lastFlip: Date, moodChanged: Bool) -> Bool {
        if !moodChanged { return true }
        return now.timeIntervalSince(lastFlip) >= minimumInterval
    }
}

// MARK: - Chase and wander

enum PetChase {
    static let minimumIdle: TimeInterval = 20
    static let cooldown: TimeInterval = 180
    /// How often Pico may even consider a peek. Combined with `chance`, this stays occasional.
    static let rollInterval: TimeInterval = 20
    static let chance: Double = 0.12

    static func shouldChase(
        enabled: Bool,
        suppressed: Bool,
        idle: TimeInterval,
        now: Date,
        cooldownUntil: Date,
        roll: Double,
        chanceMultiplier: Double = 1
    ) -> Bool {
        guard enabled, !suppressed, idle >= minimumIdle, now >= cooldownUntil else { return false }
        let chance = min(0.35, Self.chance * max(0, chanceMultiplier))
        return roll < chance
    }

    /// Step toward a point, but only a short peek so Pico never sticks to the cursor.
    static func peek(from origin: CGPoint, toward target: CGPoint, maxDistance: CGFloat = 72) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let distance = hypot(dx, dy)
        guard distance > 24 else { return origin }
        let step = min(maxDistance, distance * 0.35)
        return CGPoint(x: origin.x + dx / distance * step, y: origin.y + dy / distance * step)
    }
}

enum PetWander {
    static func step(
        origin: CGPoint,
        size: CGSize,
        visible: CGRect,
        direction: CGFloat,
        speed: CGFloat,
        alongTop: Bool = false
    ) -> (origin: CGPoint, direction: CGFloat) {
        let margin: CGFloat = 8
        let minX = visible.minX + margin
        let maxX = visible.maxX - size.width - margin
        var nextDirection: CGFloat = direction == 0 ? 1 : (direction > 0 ? 1 : -1)
        var x = origin.x + speed * nextDirection
        if x >= maxX {
            x = maxX
            nextDirection = -1
        } else if x <= minX {
            x = minX
            nextDirection = 1
        }
        let y = alongTop
            ? visible.maxY - size.height - margin
            : visible.minY + margin
        let clampedY = min(max(y, visible.minY + margin), visible.maxY - size.height - margin)
        return (CGPoint(x: x, y: clampedY), nextDirection)
    }
}

enum PetLocomotionChoice: Equatable {
    case toy
    case chase
    case wander
    case none
}

enum PetLocomotion {
    /// Toys win. A failed peek roll still allows wandering, so the two toggles stay independent.
    static func choose(hasToys: Bool, wanderEnabled: Bool, chaseRollAllowed: Bool) -> PetLocomotionChoice {
        if hasToys { return .toy }
        if chaseRollAllowed { return .chase }
        if wanderEnabled { return .wander }
        return .none
    }
}

enum PetChromeLayout {
    /// Pet-face origin inside a panel that may be wider or taller because of a speech bubble.
    static func faceOrigin(panel: CGRect, petSize: CGFloat, bubbleBelow: Bool) -> CGPoint {
        let x = panel.midX - petSize / 2
        let expanded = panel.height > petSize + 1
        let y = (expanded && bubbleBelow) ? panel.maxY - petSize : panel.minY
        return CGPoint(x: x, y: y)
    }

    static func panelOrigin(
        faceOrigin: CGPoint,
        petSize: CGFloat,
        chromeWidth: CGFloat,
        bubbleSlot: CGFloat,
        showsChrome: Bool,
        bubbleBelow: Bool
    ) -> CGPoint {
        if showsChrome, bubbleBelow {
            return CGPoint(
                x: faceOrigin.x - (chromeWidth - petSize) / 2,
                y: faceOrigin.y - bubbleSlot
            )
        }
        if showsChrome {
            return CGPoint(
                x: faceOrigin.x - (chromeWidth - petSize) / 2,
                y: faceOrigin.y
            )
        }
        return faceOrigin
    }

    static func shouldPlaceBubbleBelow(faceMaxY: CGFloat, screenMaxY: CGFloat, bubbleSlot: CGFloat) -> Bool {
        screenMaxY - faceMaxY < bubbleSlot + 8
    }
}

enum PetToyChase {
    static let catchDistance: CGFloat = 36

    static func step(from origin: CGPoint, to target: CGPoint, maxStep: CGFloat) -> (origin: CGPoint, caught: Bool) {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let distance = hypot(dx, dy)
        if distance <= catchDistance {
            return (target, true)
        }
        let step = min(maxStep, distance)
        return (CGPoint(x: origin.x + dx / distance * step, y: origin.y + dy / distance * step), false)
    }
}

enum PetToyKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case ball
    case yarn
    case laser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ball: "Ball"
        case .yarn: "Yarn"
        case .laser: "Laser"
        }
    }
}

struct PetToy: Identifiable, Equatable, Sendable {
    var id: UUID
    var kind: PetToyKind
    var origin: CGPoint

    var center: CGPoint {
        CGPoint(x: origin.x + 14, y: origin.y + 14)
    }
}

struct PetToyDrop {
    static let toySize: CGFloat = 28

    static func origin(near pet: CGPoint, petSize: CGSize, visible: CGRect, index: Int) -> CGPoint {
        let spread = CGFloat(index) * 34
        var x = pet.x + petSize.width + 40 + spread
        var y = pet.y + 12 + CGFloat(index % 2) * 22
        if x + toySize > visible.maxX - 8 {
            x = pet.x - toySize - 24 - spread
        }
        x = min(max(x, visible.minX + 8), visible.maxX - toySize - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - toySize - 8)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Care

struct CareStats: Codable, Equatable, Sendable {
    var happiness: Double
    var energy: Double
    var curiosity: Double
    var updatedAt: Date

    static let floor: Double = 0.35

    static func initial(at date: Date = Date()) -> CareStats {
        CareStats(happiness: 0.8, energy: 0.8, curiosity: 0.7, updatedAt: date)
    }

    mutating func decay(to now: Date, perHour: Double = 0.02) {
        let hours = now.timeIntervalSince(updatedAt) / 3_600
        // Ignore sub-minute gaps so a tick loop cannot grind stats down.
        guard hours >= 1.0 / 60 else { return }
        let drop = min(0.25, hours * perHour)
        happiness = max(Self.floor, happiness - drop * 0.6)
        energy = max(Self.floor, energy - drop)
        curiosity = max(Self.floor, curiosity - drop * 0.4)
        updatedAt = now
    }

    mutating func apply(_ interaction: PetInteraction) {
        switch interaction {
        case .pet:
            happiness = clamp(happiness + 0.06)
        case .feed:
            happiness = clamp(happiness + 0.08)
            energy = clamp(energy + 0.1)
        case .shoo:
            happiness = max(0.4, happiness - 0.04)
            energy = clamp(energy + 0.02)
        case .toyCatch:
            curiosity = clamp(curiosity + 0.08)
            energy = max(0.4, energy - 0.03)
        case .drag, .ask, .text, .hover:
            break
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

// MARK: - Persona

enum PetPersona: String, CaseIterable, Codable, Identifiable, Sendable {
    case friendly
    case encouraging
    case snarky
    case calm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friendly: "Friendly"
        case .encouraging: "Encouraging"
        case .snarky: "Snarky"
        case .calm: "Calm"
        }
    }

    var promptFlavor: String {
        switch self {
        case .friendly:
            "Warm, kind, and brief."
        case .encouraging:
            "Encouraging and upbeat, still concise."
        case .snarky:
            "Playfully snarky, never mean, still helpful and brief."
        case .calm:
            "Very calm, quiet, and minimal."
        }
    }
}

// MARK: - Routines and outfits

struct DayRoutine: Codable, Equatable, Sendable {
    var enabled: Bool
    var quietStartMinutes: Int
    var quietEndMinutes: Int
    var morningStretchEnabled: Bool

    static let `default` = DayRoutine(
        enabled: true,
        quietStartMinutes: 22 * 60,
        quietEndMinutes: 7 * 60,
        morningStretchEnabled: true
    )

    func isNight(at date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        let minutes = FocusSchedule.minutesSinceMidnight(date, calendar: calendar)
        return FocusSchedule.contains(
            minutes: minutes,
            start: quietStartMinutes,
            end: quietEndMinutes
        )
    }

    func shouldMorningStretch(at date: Date, lastStretchDay: String?, calendar: Calendar = .current) -> Bool {
        guard enabled, morningStretchEnabled, !isNight(at: date, calendar: calendar) else { return false }
        let minutes = FocusSchedule.minutesSinceMidnight(date, calendar: calendar)
        guard minutes >= quietEndMinutes, minutes < quietEndMinutes + 180 else { return false }
        return lastStretchDay != DayRoutine.dayKey(date, calendar: calendar)
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

enum PetSeasonOutfit: String, CaseIterable, Codable, Sendable {
    case none
    case winterScarf
    case spooky
    case celebration

    var title: String {
        switch self {
        case .none: "None"
        case .winterScarf: "Winter scarf"
        case .spooky: "Spooky"
        case .celebration: "Celebration"
        }
    }

    static func automatic(for date: Date, calendar: Calendar = .current) -> PetSeasonOutfit {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        switch month {
        case 10:
            return .spooky
        case 12 where day >= 20:
            return .celebration
        case 12, 1, 2:
            return .winterScarf
        default:
            return .none
        }
    }
}

// MARK: - Progression

struct PetUnlock: Equatable, Sendable {
    var id: String
    var title: String
    var xp: Int
}

enum PetUnlockTable {
    static let all: [PetUnlock] = [
        PetUnlock(id: "emote.wave", title: "Wave", xp: 20),
        PetUnlock(id: "emote.sparkle", title: "Sparkle", xp: 50),
        PetUnlock(id: "outfit.bow", title: "Bow", xp: 90)
    ]
}

struct PetProgression: Codable, Equatable, Sendable {
    var xp: Int
    var unlockedIDs: [String]

    init(xp: Int = 0, unlockedIDs: [String] = []) {
        self.xp = xp
        self.unlockedIDs = unlockedIDs
    }

    var level: Int { max(1, xp / 40 + 1) }

    var hasBow: Bool { unlockedIDs.contains("outfit.bow") }

    /// Awards XP from play only. Returns a newly unlocked title when one is crossed.
    mutating func award(points: Int, enabled: Bool) -> String? {
        guard enabled, points > 0 else { return nil }
        let before = Set(unlockedIDs)
        xp += points
        for unlock in PetUnlockTable.all where xp >= unlock.xp && !unlockedIDs.contains(unlock.id) {
            unlockedIDs.append(unlock.id)
        }
        let gained = PetUnlockTable.all.first { xp >= $0.xp && !before.contains($0.id) }
        return gained.map { "Level \(level) · \($0.title)" }
    }

    static func points(for interaction: PetInteraction) -> Int {
        switch interaction {
        case .pet: 5
        case .feed: 8
        case .toyCatch: 10
        case .shoo, .drag, .ask, .text, .hover: 0
        }
    }
}

// MARK: - Trait

enum UsageTrait: String, Codable, Sendable {
    case balanced
    case builder
    case chatter
    case scholar

    var title: String {
        switch self {
        case .balanced: "Still learning"
        case .builder: "Builder"
        case .chatter: "Chatter"
        case .scholar: "Scholar"
        }
    }

    /// Wander speed multiplier. Subtle only.
    var wanderSpeedMultiplier: CGFloat {
        switch self {
        case .builder: 0.85
        case .scholar: 0.65
        case .chatter: 1.05
        case .balanced: 1
        }
    }

    var chaseChanceMultiplier: Double {
        switch self {
        case .chatter: 1.35
        case .scholar: 0.75
        case .builder, .balanced: 1
        }
    }
}

struct UsageCounters: Codable, Equatable, Sendable {
    var ask: Int
    var text: Int
    var play: Int

    init(ask: Int = 0, text: Int = 0, play: Int = 0) {
        self.ask = ask
        self.text = text
        self.play = play
    }

    mutating func record(_ interaction: PetInteraction) {
        switch interaction {
        case .ask: ask += 1
        case .text: text += 1
        case .pet, .feed, .toyCatch: play += 1
        case .shoo, .drag, .hover: break
        }
    }

    var trait: UsageTrait {
        let total = ask + text + play
        guard total >= 4 else { return .balanced }
        if ask > 0, text > 0, play <= max(ask, text), abs(ask - text) <= max(2, total / 5) {
            return .scholar
        }
        if text >= ask, text >= play { return .builder }
        if ask >= text, ask >= play { return .chatter }
        if text >= ask { return .builder }
        return .chatter
    }
}

// MARK: - Performance and sound

struct PerformancePolicy: Equatable, Sendable {
    var manualEnabled: Bool
    var autoOnBattery: Bool
    var onBattery: Bool

    var isActive: Bool { manualEnabled || (autoOnBattery && onBattery) }

    /// Timeline interval. Active mode draws fewer frames.
    var animationInterval: TimeInterval { isActive ? 1.0 / 8.0 : 1.0 / 20.0 }

    var pausesAutonomy: Bool { isActive }
}

enum PetSoundEvent: String, CaseIterable, Codable, Identifiable, Sendable {
    case greet
    case feed
    case shoo
    case levelUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .greet: "Greet"
        case .feed: "Feed"
        case .shoo: "Shoo"
        case .levelUp: "Level up"
        }
    }

    /// Built-in macOS alert names. No audio files are added to the bundle.
    var systemSoundName: String {
        switch self {
        case .greet: "Pop"
        case .feed: "Tink"
        case .shoo: "Blow"
        case .levelUp: "Glass"
        }
    }
}

enum PetSoundPolicy {
    static func shouldPlay(
        volume: Double,
        eventMuted: Bool,
        focusQuiet: Bool,
        systemSilent: Bool
    ) -> Bool {
        if focusQuiet || systemSilent || eventMuted { return false }
        return volume > 0.001
    }
}

// MARK: - Autonomy snapshot

struct PetAutonomyInput: Equatable {
    var idle: TimeInterval
    var suppressed: Bool
    var night: Bool
    var focusQuiet: Bool
    var ghostActive: Bool
    var sessionBusy: Bool
    var dragging: Bool
    var mood: PetContextMood
    var trait: UsageTrait
}

enum PetAutonomy {
    /// Ambient state, if the director should replace the current pose.
    static func ambientState(_ input: PetAutonomyInput) -> PetState? {
        if input.sessionBusy || input.dragging || input.ghostActive { return nil }
        if input.focusQuiet { return .working }
        switch PetIdle.phase(idle: input.idle, suppressed: input.suppressed, night: input.night) {
        case .suppressed:
            return nil
        case .sleeping:
            return .sleeping
        case .hobby:
            return PetIdle.hobby(idle: input.idle, bias: input.trait).state
        case .awake:
            if input.mood == .idle { return .idle }
            return input.mood.petState
        }
    }
}
