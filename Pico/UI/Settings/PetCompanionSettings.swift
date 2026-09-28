import SwiftUI

struct PetCompanionSettings: View {
    @Bindable var coordinator: AppCoordinator
    @State private var settings = PetStoredSettings.default
    @State private var bundleDraft = ""
    @State private var moodDraft = PetContextMood.working

    var body: some View {
        Group {
            gestureSection
            focusSection
            behaviorSection
            careSection
            personaSection
            routineSection
            outfitSection
            progressionSection
            performanceSection
            soundSection
            accessibilitySection
        }
        .onAppear {
            settings = coordinator.petSettings()
        }
    }

    private var gestureSection: some View {
        Section("Pet gestures") {
            LabeledContent("Pet", value: "Click")
            LabeledContent("Feed", value: "Double-click")
            LabeledContent("Shoo", value: "Right-click")
            LabeledContent("Ask Pico", value: "Press and hold")
            LabeledContent("Move", value: "Drag")
            Text("Drag still repositions Pico and does not trigger a gesture. Control-click, or the menu bar, has the same actions for VoiceOver and keyboard users. Ambient gestures pause while Ask or Text Actions are busy.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Ghost Mode fades Pico while you focus a text field, then restores after a short idle. Pause hides Pico and disables hotkeys. Focus Blocks keep Pico visible but quiet.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Show pet tips") {
                coordinator.showPetTips()
            }
        }
    }

    private var focusSection: some View {
        Section("Focus Blocks") {
            if settings.focusBlocks.isEmpty {
                Text("No quiet hours yet. During a block, Pico stays visible in a calm pose and skips toys, chase, hobbies, and sounds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach($settings.focusBlocks) { $block in
                Toggle("Enabled", isOn: $block.enabled)
                    .onChange(of: block.enabled) { _, _ in save() }
                Stepper(
                    "Starts \(FocusSchedule.clockLabel(block.startMinutes))",
                    value: $block.startMinutes,
                    in: 0...23 * 60 + 59,
                    step: 15
                )
                .onChange(of: block.startMinutes) { _, _ in save() }
                Stepper(
                    "Ends \(FocusSchedule.clockLabel(block.endMinutes))",
                    value: $block.endMinutes,
                    in: 0...23 * 60 + 59,
                    step: 15
                )
                .onChange(of: block.endMinutes) { _, _ in save() }
                Button("Remove block", role: .destructive) {
                    settings.focusBlocks.removeAll { $0.id == block.id }
                    save()
                }
            }
            Button("Add Focus Block") {
                settings.focusBlocks.append(
                    FocusBlock(startMinutes: 9 * 60, endMinutes: 12 * 60)
                )
                save()
            }
        }
    }

    private var behaviorSection: some View {
        Section("Behavior") {
            Toggle("Wander along the screen edge", isOn: $settings.wanderEnabled)
                .onChange(of: settings.wanderEnabled) { _, _ in save() }
            Text("Off keeps Pico where you left them. On, Pico crawls the bottom edge and avoids the Dock and menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Cursor curiosity", isOn: $settings.chaseEnabled)
                .onChange(of: settings.chaseEnabled) { _, _ in save() }
            Text("Occasionally peeks toward the pointer. Rate-limited, and off during Ghost Mode, Focus Blocks, and Pause.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Toys", isOn: $settings.toysEnabled)
                .onChange(of: settings.toysEnabled) { _, _ in save() }
            HStack {
                ForEach(PetToyKind.allCases) { kind in
                    Button(kind.title) { coordinator.dropToy(kind) }
                        .disabled(!coordinator.canDropToys)
                }
                Button("Clear toys") { coordinator.clearToys() }
            }
            Toggle("Session bubbles", isOn: $settings.sessionBubbles)
                .onChange(of: settings.sessionBubbles) { _, _ in save() }
            Text("Short lines when Ask Pico or Text Actions succeed or fail.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var careSection: some View {
        Section("Care") {
            Toggle("Care stats", isOn: $settings.careEnabled)
                .onChange(of: settings.careEnabled) { _, _ in save() }
            if settings.careEnabled {
                LabeledContent("Happiness", value: percent(coordinator.careStats.happiness))
                LabeledContent("Energy", value: percent(coordinator.careStats.energy))
                LabeledContent("Curiosity", value: percent(coordinator.careStats.curiosity))
            }
            Text("Stored only on this Mac. Decay is slow and never drops below a gentle floor. Nothing is uploaded.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reset care stats") { coordinator.resetPetCare() }
            Button("Turn off and wipe care", role: .destructive) {
                settings.careEnabled = false
                save()
                coordinator.resetPetCare()
            }
        }
    }

    private var personaSection: some View {
        Section("Persona") {
            Picker("Dialogue", selection: $settings.persona) {
                ForEach(PetPersona.allCases) { persona in
                    Text(persona.title).tag(persona)
                }
            }
            .onChange(of: settings.persona) { _, _ in save() }
            Text("Friendly is the default. Bubbles use this voice. Ask Pico opened from the pet also gets a short tone hint.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var routineSection: some View {
        Section("Daily routine") {
            Toggle("Night quiet hours", isOn: $settings.routine.enabled)
                .onChange(of: settings.routine.enabled) { _, _ in save() }
            Stepper(
                "Night starts \(FocusSchedule.clockLabel(settings.routine.quietStartMinutes))",
                value: $settings.routine.quietStartMinutes,
                in: 0...23 * 60 + 59,
                step: 15
            )
            .onChange(of: settings.routine.quietStartMinutes) { _, _ in save() }
            Stepper(
                "Morning \(FocusSchedule.clockLabel(settings.routine.quietEndMinutes))",
                value: $settings.routine.quietEndMinutes,
                in: 0...23 * 60 + 59,
                step: 15
            )
            .onChange(of: settings.routine.quietEndMinutes) { _, _ in save() }
            Toggle("Morning stretch", isOn: $settings.routine.morningStretchEnabled)
                .onChange(of: settings.routine.morningStretchEnabled) { _, _ in save() }
            Text("Default night window is 22:00–07:00. Pico sleeps, and skips chase and hobbies. Pause and Focus Blocks still win.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var outfitSection: some View {
        Section("Outfits") {
            Toggle("Automatic seasons", isOn: $settings.autoSeason)
                .onChange(of: settings.autoSeason) { _, _ in save() }
            Text("Winter scarf, spooky (October), and celebration (late December). Drawn inside Pico’s existing size, so drag and clicks stay the same.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var progressionSection: some View {
        Section("Progress") {
            Toggle("XP and unlocks", isOn: $settings.xpEnabled)
                .onChange(of: settings.xpEnabled) { _, _ in save() }
            LabeledContent("Level", value: "\(coordinator.progression.level)")
            LabeledContent("XP", value: "\(coordinator.progression.xp)")
            LabeledContent("Trait", value: coordinator.usageTrait.title)
            Text("XP comes from petting, feeding, and toys. Trait is a local count of Ask, Text Actions, and play — Pico does not log what you type.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reset XP") { coordinator.resetPetProgression() }
            Button("Reset trait") { coordinator.resetPetUsage() }
            Button("Disable and reset progress", role: .destructive) {
                settings.xpEnabled = false
                save()
                coordinator.resetPetProgression()
                coordinator.resetPetUsage()
            }
        }
    }

    private var performanceSection: some View {
        Section("Performance") {
            Toggle("Performance Mode", isOn: $settings.performanceEnabled)
                .onChange(of: settings.performanceEnabled) { _, _ in save() }
            Toggle("Also when on battery", isOn: $settings.performanceOnBattery)
                .onChange(of: settings.performanceOnBattery) { _, _ in save() }
            Text("Lowers the animation frame rate and pauses wandering, chase, hobbies, and toys. Gestures still work.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var soundSection: some View {
        Section("Sounds") {
            Slider(value: $settings.soundVolume, in: 0...1) {
                Text("Volume")
            }
            .onChange(of: settings.soundVolume) { _, _ in save() }
            Text("Default is silent. Uses built-in macOS system sounds, so the app bundle does not grow. Output follows system volume and mute, and stays quiet during Focus Blocks.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(PetSoundEvent.allCases) { event in
                Toggle("Mute \(event.title)", isOn: muteBinding(event))
            }
        }
    }

    private var accessibilitySection: some View {
        Section("App moods") {
            Text("Built in: Xcode and VS Code work, Music grooves, Slack and Mail are social, Safari and Chrome look curious. Pico only reads the frontmost app’s identity, never window contents.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(overrideRows, id: \.bundleID) { row in
                HStack {
                    Text(row.bundleID)
                        .lineLimit(1)
                    Spacer()
                    Text(row.mood.title)
                        .foregroundStyle(.secondary)
                    Button("Remove", role: .destructive) {
                        settings.moodOverrides[row.bundleID] = nil
                        save()
                    }
                }
            }
            TextField("Bundle ID", text: $bundleDraft)
            Picker("Mood", selection: $moodDraft) {
                ForEach(PetContextMood.allCases) { mood in
                    Text(mood.title).tag(mood)
                }
            }
            Button("Add override") {
                let id = bundleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !id.isEmpty else { return }
                settings.moodOverrides[id] = moodDraft.rawValue
                bundleDraft = ""
                save()
            }
        }
    }

    private var overrideRows: [(bundleID: String, mood: PetContextMood)] {
        settings.moodOverrides.compactMap { key, value in
            guard let mood = PetContextMood(rawValue: value) else { return nil }
            return (key, mood)
        }
        .sorted { $0.bundleID < $1.bundleID }
    }

    private func muteBinding(_ event: PetSoundEvent) -> Binding<Bool> {
        Binding(
            get: { settings.mutedSounds.contains(event.rawValue) },
            set: { muted in
                if muted {
                    if !settings.mutedSounds.contains(event.rawValue) {
                        settings.mutedSounds.append(event.rawValue)
                    }
                } else {
                    settings.mutedSounds.removeAll { $0 == event.rawValue }
                }
                save()
            }
        )
    }

    private func save() {
        coordinator.savePetSettings(settings)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
