import AppKit
import Foundation

struct PetVisualState: Equatable {
    var outfit: PetSeasonOutfit
    var showBow: Bool
    var animationInterval: TimeInterval
    var pauseAnimation: Bool
    var toast: String?
}

@MainActor
final class PetDirector {
    var origin: () -> CGPoint? = { nil }
    var visibleFrame: () -> CGRect = { .zero }
    var isDragging: () -> Bool = { false }
    var isSessionBusy: () -> Bool = { false }
    var isPaused: () -> Bool = { false }
    var frontmostBundleID: () -> String? = {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    var mouseLocation: () -> CGPoint = { NSEvent.mouseLocation }
    var onBattery: () -> Bool = { PowerSource.isOnBattery() }
    var systemSilent: () -> Bool = { SystemAudio.isSilent() }

    var onApplyState: ((PetState) -> Void)?
    var onSpeech: ((String) -> Void)?
    var onMove: ((CGPoint, Bool) -> Void)?
    var onToys: (([PetToy]) -> Void)?
    var onVisual: ((PetVisualState) -> Void)?
    var onSnapshot: ((CareStats, UsageTrait, PetProgression) -> Void)?

    private(set) var settings = PetStoredSettings.default
    private(set) var toys: [PetToy] = []
    private var timer: Timer?
    private var lastInteraction = Date()
    private var lastApplied: PetState?
    private var lastMood = PetContextMood.idle
    private var lastMoodFlip = Date.distantPast
    private var chaseCooldownUntil = Date.distantPast
    private var wanderDirection: CGFloat = 1
    private var ambientLockedUntil = Date.distantPast
    private var performanceAnchor: Date?
    private var didAnnounceSleep = false
    private var didMorningStretch = false
    private var toast: String?
    private var lastVisual: PetVisualState?
    private let faceSize = CGSize(width: PicoTheme.petSize, height: PicoTheme.petSize)
    private let moodLimiter = MoodFlipLimiter()

    func start() {
        settings = PetStore.load()
        if settings.stats.updatedAt == .distantPast {
            settings.stats = .initial()
            PetStore.save(settings)
        }
        lastInteraction = Date()
        lastApplied = nil
        scheduleTimer()
        publishSnapshot()
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        clearToys()
    }

    func updateSettings(_ incoming: PetStoredSettings) {
        var merged = incoming
        merged.stats = settings.stats
        merged.progression = settings.progression
        merged.usage = settings.usage
        merged.lastStretchDay = settings.lastStretchDay
        settings = merged
        PetStore.save(settings)
        scheduleTimer()
        publishSnapshot()
        publishVisual(pauseAnimation: false)
    }

    func interact(_ interaction: PetInteraction) {
        let now = Date()
        if interaction != .hover {
            lastInteraction = now
            didAnnounceSleep = false
        } else if lastApplied == .sleeping {
            lastInteraction = now
            didAnnounceSleep = false
            onApplyState?(.curious)
            lastApplied = .curious
            onSpeech?(PetSpeechLines.line(for: .wake, persona: settings.persona))
        }
        ambientLockedUntil = now.addingTimeInterval(interaction == .hover ? 0 : 1.4)
        if settings.careEnabled {
            settings.stats.apply(interaction)
        }
        settings.usage.record(interaction)
        let points = PetProgression.points(for: interaction)
        if let unlocked = settings.progression.award(points: points, enabled: settings.xpEnabled) {
            toast = unlocked
            onSpeech?(unlocked)
            play(.levelUp)
        }
        if interaction == .shoo || interaction == .drag {
            clearToys()
        }
        persistProgress()
        publishSnapshot()
    }

    func dropToy(_ kind: PetToyKind) {
        guard settings.toysEnabled, !isPaused(), !focusQuiet() else { return }
        let pet = origin() ?? .zero
        let visible = visibleFrame()
        let toyOrigin = PetToyDrop.origin(
            near: pet,
            petSize: faceSize,
            visible: visible,
            index: toys.count
        )
        toys.append(PetToy(id: UUID(), kind: kind, origin: toyOrigin))
        onToys?(toys)
        lastInteraction = Date()
    }

    func clearToys() {
        guard !toys.isEmpty else { return }
        toys = []
        onToys?([])
    }

    func dismissToast() {
        toast = nil
        publishVisual(pauseAnimation: false)
    }

    var allowsToys: Bool {
        settings.toysEnabled && !isPaused() && !focusQuiet()
    }

    func noteSessionPose(_ state: PetState) {
        guard state.isTransient else { return }
        let delay: TimeInterval = state == .celebrating ? 1.3 : 1.0
        ambientLockedUntil = Date().addingTimeInterval(delay)
    }

    func currentSettings() -> PetStoredSettings { settings }

    func resetCare() {
        settings.stats = .initial()
        persistProgress()
        publishSnapshot()
    }

    func resetProgression() {
        settings.progression = PetProgression()
        toast = nil
        persistProgress()
        publishSnapshot()
    }

    func resetUsage() {
        settings.usage = UsageCounters()
        persistProgress()
        publishSnapshot()
    }

    func tick(now: Date = Date(), roll: Double = Double.random(in: 0..<1)) {
        guard !isPaused() else { return }
        if settings.careEnabled {
            let before = settings.stats
            settings.stats.decay(to: now)
            if settings.stats != before {
                persistProgress()
            }
        }

        let performance = PerformancePolicy(
            manualEnabled: settings.performanceEnabled,
            autoOnBattery: settings.performanceOnBattery,
            onBattery: onBattery()
        )
        if performance.pausesAutonomy {
            if performanceAnchor == nil { performanceAnchor = now }
        } else if let anchor = performanceAnchor {
            lastInteraction = lastInteraction.addingTimeInterval(now.timeIntervalSince(anchor))
            performanceAnchor = nil
        }

        let idleEnd = performanceAnchor ?? now
        let idle = max(0, idleEnd.timeIntervalSince(lastInteraction))
        let night = settings.routine.isNight(at: now)
        let focus = focusQuiet(at: now)
        let ghost = isGhostActive
        let session = isSessionBusy()
        let dragging = isDragging()
        let suppressed = ghost || performance.pausesAutonomy || dragging

        let mood = resolvedMood(at: now)
        let input = PetAutonomyInput(
            idle: idle,
            suppressed: suppressed,
            night: night,
            focusQuiet: focus,
            ghostActive: ghost,
            sessionBusy: session,
            dragging: dragging,
            mood: mood,
            trait: settings.usage.trait
        )

        let sleeping = PetIdle.phase(idle: idle, suppressed: suppressed, night: night) == .sleeping
            && !session && !dragging && !ghost && !focus
        publishVisual(pauseAnimation: sleeping)

        guard now >= ambientLockedUntil else { return }
        guard !session, !dragging else { return }

        if let state = PetAutonomy.ambientState(input), state != lastApplied {
            lastApplied = state
            onApplyState?(state)
            if state == .sleeping, !didAnnounceSleep {
                didAnnounceSleep = true
                onSpeech?(PetSpeechLines.line(for: .sleep, persona: settings.persona))
            }
            if case .hobby = PetIdle.phase(idle: idle, suppressed: suppressed, night: night), !suppressed, !focus, !night {
                let hobby = PetIdle.hobby(idle: idle, bias: settings.usage.trait)
                onSpeech?(hobby.speech)
            }
        }

        maybeMorningStretch(at: now, suppressed: suppressed || focus || ghost || session)

        guard !suppressed, !focus, !night, !sleeping else { return }

        if !toys.isEmpty, let petOrigin = origin() {
            let target = toys[0].center
            let chased = PetToyChase.step(from: petOrigin, to: target, maxStep: 22)
            onMove?(chased.origin, false)
            if chased.caught {
                toys.removeFirst()
                onToys?(toys)
                interact(.toyCatch)
                onApplyState?(.celebrating)
                lastApplied = .celebrating
                ambientLockedUntil = now.addingTimeInterval(1.2)
                onSpeech?(PetSpeechLines.line(for: .feed, persona: settings.persona))
            }
        } else if phaseAllowsLocomotion(idle: idle, suppressed: suppressed, night: night),
                  settings.wanderEnabled,
                  let petOrigin = origin() {
            let speed = 10 * settings.usage.trait.wanderSpeedMultiplier
            let stepped = PetWander.step(
                origin: petOrigin,
                size: faceSize,
                visible: visibleFrame(),
                direction: wanderDirection,
                speed: speed
            )
            wanderDirection = stepped.direction
            onMove?(stepped.origin, false)
        } else if phaseAllowsLocomotion(idle: idle, suppressed: suppressed, night: night),
                  PetChase.shouldChase(
            enabled: settings.chaseEnabled,
            suppressed: false,
            idle: idle,
            now: now,
            cooldownUntil: chaseCooldownUntil,
            roll: roll,
            chanceMultiplier: settings.usage.trait.chaseChanceMultiplier
        ), let petOrigin = origin() {
            let cursor = mouseLocation()
            let next = PetChase.peek(from: petOrigin, toward: cursor)
            if next != petOrigin {
                onMove?(next, true)
                onSpeech?(PetSpeechLines.line(for: .chase, persona: settings.persona))
                onApplyState?(.curious)
                lastApplied = .curious
                ambientLockedUntil = now.addingTimeInterval(1.6)
            }
            chaseCooldownUntil = now.addingTimeInterval(PetChase.cooldown)
        }
    }

    private var isGhostActive = false

    func setGhostActive(_ active: Bool) {
        isGhostActive = active
    }

    func playGreetingIfNeeded() {
        play(.greet)
    }

    func playFeed() { play(.feed) }
    func playShoo() { play(.shoo) }

    private func play(_ event: PetSoundEvent) {
        let muted = settings.mutedSounds.contains(event.rawValue)
        guard PetSoundPolicy.shouldPlay(
            volume: settings.soundVolume,
            eventMuted: muted,
            focusQuiet: focusQuiet(),
            systemSilent: systemSilent()
        ) else { return }
        PetSoundPlayer.play(event, volume: settings.soundVolume)
    }

    private func phaseAllowsLocomotion(idle: TimeInterval, suppressed: Bool, night: Bool) -> Bool {
        if case .awake = PetIdle.phase(idle: idle, suppressed: suppressed, night: night) {
            return true
        }
        return false
    }

    private func focusQuiet(at date: Date = Date()) -> Bool {
        FocusSchedule.isQuiet(at: date, blocks: settings.focusBlocks)
    }

    private func resolvedMood(at date: Date) -> PetContextMood {
        let raw = AppMoodCatalog.mood(bundleID: frontmostBundleID(), overrides: settings.moodMap)
        let changed = raw != lastMood
        guard moodLimiter.shouldApply(now: date, lastFlip: lastMoodFlip, moodChanged: changed) else {
            return lastMood
        }
        if changed {
            lastMood = raw
            lastMoodFlip = date
        }
        return lastMood
    }

    private func maybeMorningStretch(at date: Date, suppressed: Bool) {
        guard !suppressed else { return }
        guard settings.routine.shouldMorningStretch(at: date, lastStretchDay: settings.lastStretchDay) else { return }
        guard !didMorningStretch else { return }
        didMorningStretch = true
        settings.lastStretchDay = DayRoutine.dayKey(date)
        onApplyState?(.love)
        lastApplied = .love
        ambientLockedUntil = date.addingTimeInterval(1.6)
        onSpeech?(PetSpeechLines.line(for: .morning, persona: settings.persona))
        persistProgress()
    }

    private func publishVisual(pauseAnimation: Bool) {
        let performance = PerformancePolicy(
            manualEnabled: settings.performanceEnabled,
            autoOnBattery: settings.performanceOnBattery,
            onBattery: onBattery()
        )
        let outfit = settings.autoSeason ? PetSeasonOutfit.automatic(for: Date()) : .none
        let visual = PetVisualState(
            outfit: outfit,
            showBow: settings.progression.hasBow,
            animationInterval: performance.animationInterval,
            pauseAnimation: pauseAnimation,
            toast: toast
        )
        guard visual != lastVisual else { return }
        lastVisual = visual
        onVisual?(visual)
    }

    private func publishSnapshot() {
        onSnapshot?(settings.stats, settings.usage.trait, settings.progression)
    }

    private func persistProgress() {
        PetStore.save(settings)
        publishSnapshot()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let performance = PerformancePolicy(
            manualEnabled: settings.performanceEnabled,
            autoOnBattery: settings.performanceOnBattery,
            onBattery: onBattery()
        )
        let interval: TimeInterval = performance.pausesAutonomy ? 1.5 : 0.6
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
