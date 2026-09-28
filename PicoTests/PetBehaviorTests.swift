import CoreGraphics
import XCTest
@testable import Pico

final class PetBehaviorTests: XCTestCase {
    func testGestureDisambiguation() {
        XCTAssertEqual(
            PetClickResolver.resolve(dragged: true, longPress: false, clickCount: 1, rightClick: false, controlClick: false),
            .drag
        )
        XCTAssertEqual(
            PetClickResolver.resolve(dragged: false, longPress: false, clickCount: 1, rightClick: false, controlClick: false),
            .pet
        )
        XCTAssertEqual(
            PetClickResolver.resolve(dragged: false, longPress: false, clickCount: 2, rightClick: false, controlClick: false),
            .feed
        )
        XCTAssertEqual(
            PetClickResolver.resolve(dragged: false, longPress: true, clickCount: 1, rightClick: false, controlClick: false),
            .ask
        )
        XCTAssertEqual(
            PetClickResolver.resolve(dragged: false, longPress: false, clickCount: 1, rightClick: true, controlClick: false),
            .shoo
        )
        XCTAssertEqual(
            PetClickResolver.resolve(dragged: false, longPress: false, clickCount: 1, rightClick: true, controlClick: true),
            .menu
        )
    }

    func testIdlePhases() {
        XCTAssertEqual(PetIdle.phase(idle: 10, suppressed: false, night: false), .awake)
        guard case .hobby = PetIdle.phase(idle: 45, suppressed: false, night: false) else {
            return XCTFail("Expected a hobby")
        }
        XCTAssertEqual(PetIdle.phase(idle: 300, suppressed: false, night: false), .sleeping)
        XCTAssertEqual(PetIdle.phase(idle: 20, suppressed: false, night: true), .sleeping)
        XCTAssertEqual(PetIdle.phase(idle: 400, suppressed: true, night: true), .suppressed)
    }

    func testHobbyCatalogHasFiveVariants() {
        XCTAssertEqual(PetHobby.allCases.count, 5)
        XCTAssertEqual(PetIdle.hobby(idle: 90, bias: .scholar), .reading)
        XCTAssertEqual(PetIdle.hobby(idle: 90, bias: .builder), .doodling)
    }

    func testFocusBlockOvernight() {
        let block = FocusBlock(startMinutes: 22 * 60, endMinutes: 7 * 60)
        XCTAssertTrue(FocusSchedule.contains(minutes: 23 * 60, start: block.startMinutes, end: block.endMinutes))
        XCTAssertTrue(FocusSchedule.contains(minutes: 6 * 60, start: block.startMinutes, end: block.endMinutes))
        XCTAssertFalse(FocusSchedule.contains(minutes: 12 * 60, start: block.startMinutes, end: block.endMinutes))
        XCTAssertFalse(FocusSchedule.contains(minutes: 9 * 60, start: 9 * 60, end: 9 * 60))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let late = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 23, minute: 15))!
        XCTAssertTrue(FocusSchedule.isQuiet(at: late, blocks: [block], calendar: calendar))
    }

    func testAppMoodUsesOverrideThenBuiltInThenIdle() {
        XCTAssertEqual(AppMoodCatalog.mood(bundleID: "com.apple.dt.Xcode", overrides: [:]), .working)
        XCTAssertEqual(AppMoodCatalog.mood(bundleID: "com.apple.Music", overrides: [:]), .groove)
        XCTAssertEqual(
            AppMoodCatalog.mood(bundleID: "com.apple.dt.Xcode", overrides: ["com.apple.dt.Xcode": .social]),
            .social
        )
        XCTAssertEqual(AppMoodCatalog.mood(bundleID: "com.example.unknown", overrides: [:]), .idle)
        XCTAssertEqual(AppMoodCatalog.mood(bundleID: nil, overrides: [:]), .idle)
    }

    func testMoodFlipIsRateLimited() {
        let limiter = MoodFlipLimiter(minimumInterval: 8)
        let now = Date()
        XCTAssertFalse(limiter.shouldApply(now: now, lastFlip: now.addingTimeInterval(-2), moodChanged: true))
        XCTAssertTrue(limiter.shouldApply(now: now, lastFlip: now.addingTimeInterval(-9), moodChanged: true))
        XCTAssertTrue(limiter.shouldApply(now: now, lastFlip: now, moodChanged: false))
    }

    func testChaseIsRareAndSuppressed() {
        let now = Date()
        XCTAssertFalse(PetChase.shouldChase(
            enabled: true, suppressed: true, idle: 30, now: now, cooldownUntil: .distantPast, roll: 0
        ))
        XCTAssertFalse(PetChase.shouldChase(
            enabled: false, suppressed: false, idle: 30, now: now, cooldownUntil: .distantPast, roll: 0
        ))
        XCTAssertFalse(PetChase.shouldChase(
            enabled: true, suppressed: false, idle: 5, now: now, cooldownUntil: .distantPast, roll: 0
        ))
        XCTAssertFalse(PetChase.shouldChase(
            enabled: true, suppressed: false, idle: 40, now: now, cooldownUntil: now.addingTimeInterval(10), roll: 0
        ))
        XCTAssertTrue(PetChase.shouldChase(
            enabled: true, suppressed: false, idle: 40, now: now, cooldownUntil: .distantPast, roll: 0.01
        ))
        XCTAssertFalse(PetChase.shouldChase(
            enabled: true, suppressed: false, idle: 40, now: now, cooldownUntil: .distantPast, roll: 0.9
        ))
        XCTAssertEqual(PetChase.rollInterval, 20, accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(PetChase.cooldown, 180)
    }

    func testLocomotionPrefersToysThenChaseThenWander() {
        XCTAssertEqual(PetLocomotion.choose(hasToys: true, wanderEnabled: true, chaseRollAllowed: true), .toy)
        XCTAssertEqual(PetLocomotion.choose(hasToys: false, wanderEnabled: true, chaseRollAllowed: true), .chase)
        XCTAssertEqual(PetLocomotion.choose(hasToys: false, wanderEnabled: true, chaseRollAllowed: false), .wander)
        XCTAssertEqual(PetLocomotion.choose(hasToys: false, wanderEnabled: false, chaseRollAllowed: false), .none)
        XCTAssertTrue(PetIdle.allowsLocomotion(.awake))
        XCTAssertTrue(PetIdle.allowsLocomotion(.hobby(.reading)))
        XCTAssertFalse(PetIdle.allowsLocomotion(.sleeping))
        XCTAssertFalse(PetIdle.allowsLocomotion(.suppressed))
    }

    func testSpeechChromeKeepsThePetFacePut() {
        let pet: CGFloat = 56
        let bubble: CGFloat = 120
        let slot: CGFloat = 34
        let face = CGPoint(x: 200, y: 80)
        let origin = PetChromeLayout.panelOrigin(
            faceOrigin: face,
            petSize: pet,
            chromeWidth: bubble,
            bubbleSlot: slot,
            showsChrome: true,
            bubbleBelow: false
        )
        let panel = CGRect(x: origin.x, y: origin.y, width: bubble, height: pet + slot)
        let recovered = PetChromeLayout.faceOrigin(panel: panel, petSize: pet, bubbleBelow: false)
        XCTAssertEqual(recovered.x, face.x, accuracy: 0.1)
        XCTAssertEqual(recovered.y, face.y, accuracy: 0.1)

        let again = PetChromeLayout.panelOrigin(
            faceOrigin: recovered,
            petSize: pet,
            chromeWidth: bubble,
            bubbleSlot: slot,
            showsChrome: true,
            bubbleBelow: false
        )
        XCTAssertEqual(again.x, origin.x, accuracy: 0.1)
        XCTAssertEqual(again.y, origin.y, accuracy: 0.1)

        let below = PetChromeLayout.panelOrigin(
            faceOrigin: face,
            petSize: pet,
            chromeWidth: bubble,
            bubbleSlot: slot,
            showsChrome: true,
            bubbleBelow: true
        )
        let belowPanel = CGRect(x: below.x, y: below.y, width: bubble, height: pet + slot)
        let belowFace = PetChromeLayout.faceOrigin(panel: belowPanel, petSize: pet, bubbleBelow: true)
        XCTAssertEqual(belowFace.x, face.x, accuracy: 0.1)
        XCTAssertEqual(belowFace.y, face.y, accuracy: 0.1)
        XCTAssertTrue(PetChromeLayout.shouldPlaceBubbleBelow(faceMaxY: 790, screenMaxY: 800, bubbleSlot: slot))
        XCTAssertFalse(PetChromeLayout.shouldPlaceBubbleBelow(faceMaxY: 400, screenMaxY: 800, bubbleSlot: slot))
    }

    func testWanderStaysInVisibleFrameAndFlips() {
        let visible = CGRect(x: 0, y: 40, width: 800, height: 500)
        let size = CGSize(width: 56, height: 56)
        let origin = CGPoint(x: visible.maxX - size.width - 4, y: 0)
        let stepped = PetWander.step(origin: origin, size: size, visible: visible, direction: 1, speed: 30)
        XCTAssertLessThanOrEqual(stepped.origin.x + size.width, visible.maxX)
        XCTAssertGreaterThanOrEqual(stepped.origin.y, visible.minY)
        XCTAssertEqual(stepped.direction, -1)
        XCTAssertEqual(stepped.origin.y, visible.minY + 8, accuracy: 0.1)
    }

    func testToyQueueChaseAndDrop() {
        let visible = CGRect(x: 0, y: 0, width: 500, height: 400)
        let origin = PetToyDrop.origin(
            near: CGPoint(x: 400, y: 40),
            petSize: CGSize(width: 56, height: 56),
            visible: visible,
            index: 0
        )
        XCTAssertGreaterThanOrEqual(origin.x, visible.minX)
        XCTAssertLessThanOrEqual(origin.x + PetToyDrop.toySize, visible.maxX)

        let caught = PetToyChase.step(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 20, y: 12), maxStep: 30)
        XCTAssertTrue(caught.caught)
        let moving = PetToyChase.step(from: .zero, to: CGPoint(x: 200, y: 0), maxStep: 22)
        XCTAssertFalse(moving.caught)
        XCTAssertEqual(moving.origin.x, 22, accuracy: 0.1)
    }

    func testCareDecayIsSlowAndGesturesStayGentle() {
        var stats = CareStats.initial(at: Date().addingTimeInterval(-48 * 3600))
        stats.decay(to: Date())
        XCTAssertGreaterThanOrEqual(stats.happiness, CareStats.floor)
        XCTAssertGreaterThanOrEqual(stats.energy, CareStats.floor)
        let before = stats.happiness
        stats.apply(.shoo)
        XCTAssertGreaterThan(stats.happiness, 0.3)
        XCTAssertLessThan(stats.happiness, before + 0.001)
        stats.apply(.feed)
        XCTAssertGreaterThan(stats.happiness, before - 0.2)
    }

    func testDayRoutineNightAndMorningStretch() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let routine = DayRoutine.default
        let night = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 23))!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 8))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 15))!
        XCTAssertTrue(routine.isNight(at: night, calendar: calendar))
        XCTAssertFalse(routine.isNight(at: morning, calendar: calendar))
        XCTAssertTrue(routine.shouldMorningStretch(at: morning, lastStretchDay: nil, calendar: calendar))
        XCTAssertFalse(routine.shouldMorningStretch(at: afternoon, lastStretchDay: nil, calendar: calendar))
        XCTAssertFalse(
            routine.shouldMorningStretch(
                at: morning,
                lastStretchDay: DayRoutine.dayKey(morning, calendar: calendar),
                calendar: calendar
            )
        )
    }

    func testSeasonalOutfits() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let october = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 25))!
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let june = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        XCTAssertEqual(PetSeasonOutfit.automatic(for: october, calendar: calendar), .spooky)
        XCTAssertEqual(PetSeasonOutfit.automatic(for: december, calendar: calendar), .celebration)
        XCTAssertEqual(PetSeasonOutfit.automatic(for: january, calendar: calendar), .winterScarf)
        XCTAssertEqual(PetSeasonOutfit.automatic(for: june, calendar: calendar), .none)
    }

    func testXPUnlocksOnlyFromPlayAndCanReset() {
        var progress = PetProgression()
        XCTAssertNil(progress.award(points: PetProgression.points(for: .ask), enabled: true))
        XCTAssertEqual(progress.xp, 0)
        XCTAssertEqual(progress.award(points: 20, enabled: true), "Level 1 · Wave")
        XCTAssertTrue(progress.unlockedIDs.contains("emote.wave"))
        XCTAssertNil(progress.award(points: 10, enabled: false))
        XCTAssertEqual(progress.xp, 20)
        progress = PetProgression()
        XCTAssertEqual(progress.xp, 0)
        XCTAssertEqual(PetProgression.points(for: .pet), 5)
        XCTAssertEqual(PetProgression.points(for: .feed), 8)
        XCTAssertEqual(PetProgression.points(for: .toyCatch), 10)
        XCTAssertEqual(PetUnlockTable.all.count, 3)
    }

    func testUsageTraitIsLocalAndResettable() {
        var usage = UsageCounters()
        XCTAssertEqual(usage.trait, .balanced)
        usage.record(.text)
        usage.record(.text)
        usage.record(.text)
        usage.record(.text)
        XCTAssertEqual(usage.trait, .builder)
        usage = UsageCounters(ask: 5, text: 5, play: 1)
        XCTAssertEqual(usage.trait, .scholar)
        usage = UsageCounters(ask: 6, text: 1, play: 1)
        XCTAssertEqual(usage.trait, .chatter)
        XCTAssertLessThan(UsageTrait.scholar.wanderSpeedMultiplier, UsageTrait.balanced.wanderSpeedMultiplier)
    }

    func testBatteryPowerState() {
        XCTAssertTrue(PowerSource.isBatteryPower("Battery Power"))
        XCTAssertFalse(PowerSource.isBatteryPower("AC Power"))
        XCTAssertFalse(PowerSource.isBatteryPower(nil))
    }

    func testPerformanceAndSoundPolicies() {
        let off = PerformancePolicy(manualEnabled: false, autoOnBattery: false, onBattery: true)
        XCTAssertFalse(off.isActive)
        XCTAssertEqual(off.animationInterval, 1.0 / 20.0, accuracy: 0.0001)
        let battery = PerformancePolicy(manualEnabled: false, autoOnBattery: true, onBattery: true)
        XCTAssertTrue(battery.isActive)
        XCTAssertGreaterThan(battery.animationInterval, off.animationInterval)
        XCTAssertTrue(battery.pausesAutonomy)
        XCTAssertFalse(PetSoundPolicy.shouldPlay(volume: 0, eventMuted: false, focusQuiet: false, systemSilent: false))
        XCTAssertFalse(PetSoundPolicy.shouldPlay(volume: 0.4, eventMuted: false, focusQuiet: true, systemSilent: false))
        XCTAssertFalse(PetSoundPolicy.shouldPlay(volume: 0.4, eventMuted: false, focusQuiet: false, systemSilent: true))
        XCTAssertFalse(PetSoundPolicy.shouldPlay(volume: 0.4, eventMuted: true, focusQuiet: false, systemSilent: false))
        XCTAssertTrue(PetSoundPolicy.shouldPlay(volume: 0.4, eventMuted: false, focusQuiet: false, systemSilent: false))
    }

    func testAmbientStatePriority() {
        let base = PetAutonomyInput(
            idle: 10,
            suppressed: false,
            night: false,
            focusQuiet: false,
            ghostActive: false,
            sessionBusy: false,
            dragging: false,
            mood: .working,
            trait: .balanced
        )
        XCTAssertEqual(PetAutonomy.ambientState(base), .working)
        var session = base
        session.sessionBusy = true
        XCTAssertNil(PetAutonomy.ambientState(session))
        var focus = base
        focus.focusQuiet = true
        focus.idle = 400
        XCTAssertEqual(PetAutonomy.ambientState(focus), .working)
        var night = base
        night.night = true
        night.idle = 30
        XCTAssertEqual(PetAutonomy.ambientState(night), .sleeping)
        var ghost = base
        ghost.ghostActive = true
        XCTAssertNil(PetAutonomy.ambientState(ghost))
    }

    func testSettingsRoundTrip() {
        let defaults = UserDefaults(suiteName: "PetBehaviorTests")!
        defaults.removePersistentDomain(forName: "PetBehaviorTests")
        var settings = PetStoredSettings.default
        settings.persona = .snarky
        settings.focusBlocks = [FocusBlock(startMinutes: 9 * 60, endMinutes: 11 * 60)]
        settings.moodOverrides = ["com.example.app": PetContextMood.working.rawValue]
        PetStore.save(settings, to: defaults)
        let loaded = PetStore.load(from: defaults)
        XCTAssertEqual(loaded.persona, .snarky)
        XCTAssertEqual(loaded.focusBlocks.count, 1)
        XCTAssertEqual(loaded.moodMap["com.example.app"], .working)
        XCTAssertEqual(loaded.soundVolume, 0)
        XCTAssertFalse(loaded.wanderEnabled)
        XCTAssertTrue(loaded.chaseEnabled)
    }
}
