import AppKit
import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    var petState: PetState = .idle
    var isPaused = false
    var hotkeyRegistrationFailed = false
    var hotkeyAskFailed = false
    var hotkeyTextFailed = false
    var careStats = CareStats.initial()
    var usageTrait = UsageTrait.balanced
    var progression = PetProgression()

    private let environment: AppEnvironment
    private let petPanel = PetPanelController()
    private let menuBar = MenuBarController()
    private let ghostModeMonitor = GhostModeMonitor()
    private let director = PetDirector()

    private var assistantPanel: FloatingPanel?
    private var textPanel: FloatingPanel?
    private var historyPanel: FloatingPanel?
    private var settingsWindow: NSWindow?
    private var onboardingPanel: FloatingPanel?
    private var tipsPanel: FloatingPanel?

    private var assistantViewModel: AssistantViewModel?
    private var textViewModel: TextActionMenuViewModel?
    private var historyViewModel: HistoryViewModel?
    private var successResetTask: Task<Void, Never>?
    /// True while Ask Pico or Text Actions is on screen. Ambient "working" is not a session.
    private var aiSessionActive = false
    private var textActionsTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
        petPanel.attach(coordinator: self)
        menuBar.attach(coordinator: self)

        environment.screenAgent.hideChrome = { [weak self] in
            self?.assistantPanel?.orderOut(nil)
            self?.historyPanel?.orderOut(nil)
        }
        environment.screenAgent.restoreChrome = { [weak self] in
            self?.assistantPanel?.makeKeyAndOrderFrontActivating()
        }

        environment.hotkeyManager.onAsk = { [weak self] in
            self?.toggleAssistant()
        }
        environment.hotkeyManager.onTextActions = { [weak self] in
            self?.showTextActions()
        }

        ghostModeMonitor.onGhostActiveChanged = { [weak self] active in
            guard let self else { return }
            self.petPanel.setGhosted(active)
            self.director.setGhostActive(active)
        }

        wirePetDirector()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.petPanel.handleDisplayChange()
            }
        }
    }

    func start() {
        isPaused = UserDefaults.standard.bool(forKey: PreferenceKey.isPaused)
        menuBar.reloadMenu()
        syncGhostModeEnabled()

        if !UserDefaults.standard.bool(forKey: PreferenceKey.hasCompletedOnboarding) {
            showOnboarding()
        } else {
            enterIdleMode()
        }
    }

    func enterIdleMode() {
        if !isPaused {
            environment.hotkeyManager.register()
            hotkeyAskFailed = environment.hotkeyManager.registrationFailedAsk
            hotkeyTextFailed = environment.hotkeyManager.registrationFailedText
            hotkeyRegistrationFailed = hotkeyAskFailed || hotkeyTextFailed
            updatePetVisibility()
            startGhostModeIfNeeded()
            director.start()
            maybeShowPetTips()
        }
        menuBar.reloadMenu()
    }

    func showAssistant(conversation: Conversation? = nil, fromPet: Bool = false) {
        guard !isPaused else { return }
        hideTextPanel()
        hideHistory()

        if assistantPanel?.isVisible == true, conversation == nil {
            if fromPet {
                assistantPanel?.makeKeyAndOrderFrontActivating()
                return
            }
            hideAssistant()
            return
        }

        if assistantPanel?.isVisible != true {
            environment.screenAgent.rememberTargetApp()
        }

        let viewModel = assistantViewModel ?? AssistantViewModel(
            aiService: environment.aiService,
            store: environment.conversationStore,
            screenAgent: environment.screenAgent
        )
        viewModel.toneHint = fromPet ? director.currentSettings().persona.promptFlavor : nil
        viewModel.onPetState = { [weak self] state in
            self?.applySessionPetState(state)
        }
        director.interact(.ask)
        if let conversation {
            viewModel.load(conversation: conversation)
        }
        assistantViewModel = viewModel

        let root = AssistantView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.hideAssistant() },
            onOpenHistory: { [weak self] in self?.showHistory() }
        )

        let size = assistantSize()
        let origin = panelOriginNearPet(size: size)

        let panel = assistantPanel ?? FloatingPanel(
            contentRect: NSRect(origin: origin, size: size)
        )
        panel.onEscape = { [weak self] in self?.hideAssistant() }
        panel.onResizeEnd = { size in
            UserDefaults.standard.set(size.width, forKey: PreferenceKey.assistantWidth)
            UserDefaults.standard.set(size.height, forKey: PreferenceKey.assistantHeight)
        }
        panel.minSize = NSSize(
            width: PicoTheme.assistantMinWidth,
            height: PicoTheme.assistantMinHeight
        )
        panel.setSwiftUIContent(root)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.makeKeyAndOrderFrontActivating()
        assistantPanel = panel
        aiSessionActive = true
        setPetState(.listening)
    }

    func toggleAssistant() {
        if assistantPanel?.isVisible == true {
            hideAssistant()
        } else {
            showAssistant()
        }
    }

    func hideAssistant() {
        // Only cancel in-flight generation — keep multi-turn AI session across panel closes.
        if assistantViewModel?.isSending == true {
            assistantViewModel?.cancel()
        }
        assistantPanel?.orderOut(nil)
        aiSessionActive = false
        setPetState(.idle)
    }

    func showTextActions() {
        guard !isPaused else { return }
        hideAssistant()
        hideHistory()
        aiSessionActive = true

        // Abandon any prior text-actions session so clipboard is restored.
        textActionsTask?.cancel()
        textViewModel?.abandon()

        let viewModel = TextActionMenuViewModel(processor: environment.textProcessor)
        viewModel.onPetState = { [weak self] state in
            self?.applySessionPetState(state)
        }
        director.interact(.text)
        viewModel.onFinished = { [weak self] in
            self?.hideTextPanel()
        }
        textViewModel = viewModel

        textActionsTask = Task {
            // Capture while the source app still has focus — before showing Pico's panel.
            do {
                let capture = try await self.environment.textProcessor.captureSelection()
                guard !Task.isCancelled, self.textViewModel === viewModel else { return }
                viewModel.apply(capture: capture)
            } catch let error as TextProcessor.CaptureError {
                guard !Task.isCancelled, self.textViewModel === viewModel else { return }
                viewModel.apply(error: error)
            } catch {
                guard !Task.isCancelled, self.textViewModel === viewModel else { return }
                viewModel.apply(error: .clipboardFailed)
            }

            guard !Task.isCancelled, self.textViewModel === viewModel else { return }

            let root = TextActionMenu(
                viewModel: viewModel,
                onClose: { [weak self] in self?.hideTextPanel() }
            )

            let panel = self.textPanel ?? FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 280),
                styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]
            )
            panel.onEscape = { [weak self] in
                self?.textViewModel?.cancel()
                self?.hideTextPanel()
            }
            panel.setSwiftUIContent(root)
            self.positionTextPanel(panel)
            // Non-activating: do not steal focus from the source app.
            panel.orderFrontRegardless()
            self.textPanel = panel
            self.aiSessionActive = true
            self.repositionTextPanelIfNeeded()
        }
    }

    func hideTextPanel() {
        textActionsTask?.cancel()
        textActionsTask = nil
        textViewModel?.abandon()
        textViewModel = nil
        textPanel?.orderOut(nil)
        aiSessionActive = false
        if petState == .thinking || petState == .listening || petState == .curious {
            setPetState(.idle)
        }
    }

    func showHistory() {
        let viewModel = historyViewModel ?? HistoryViewModel(store: environment.conversationStore)
        viewModel.reload()
        historyViewModel = viewModel

        let root = HistoryView(
            viewModel: viewModel,
            onSelect: { [weak self] conversation in
                self?.hideHistory()
                self?.showAssistant(conversation: conversation)
            },
            onClose: { [weak self] in self?.hideHistory() }
        )

        let panel = historyPanel ?? FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420)
        )
        panel.onEscape = { [weak self] in self?.hideHistory() }
        panel.setSwiftUIContent(root)
        let size = NSSize(width: 320, height: 420)
        let origin: CGPoint
        if let assistantFrame = assistantPanel?.frame, assistantPanel?.isVisible == true {
            let screen = assistantPanel?.screen ?? ScreenManager.primaryScreen
            var x = assistantFrame.minX - size.width - PicoTheme.panelGap
            if x < screen.visibleFrame.minX + PicoTheme.screenMargin {
                x = assistantFrame.maxX + PicoTheme.panelGap
            }
            origin = CGPoint(
                x: x,
                y: max(screen.visibleFrame.minY + PicoTheme.screenMargin, assistantFrame.maxY - size.height)
            )
        } else {
            origin = panelOriginNearPet(size: size)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.makeKeyAndOrderFrontActivating()
        historyPanel = panel
    }

    func hideHistory() {
        historyPanel?.orderOut(nil)
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 720),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Pico Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(coordinator: self))
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboarding() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .fullSizeContentView]
        )
        panel.title = "Welcome to Pico"
        panel.setSwiftUIContent(
            OnboardingView { [weak self] in
                self?.onboardingPanel?.orderOut(nil)
                self?.onboardingPanel = nil
                self?.enterIdleMode()
            }
        )
        panel.center()
        panel.makeKeyAndOrderFrontActivating()
        onboardingPanel = panel
    }

    func togglePause() {
        isPaused.toggle()
        UserDefaults.standard.set(isPaused, forKey: PreferenceKey.isPaused)
        if isPaused {
            environment.hotkeyManager.unregister()
            ghostModeMonitor.stop()
            director.stop()
            hideAssistant()
            hideTextPanel()
            hideHistory()
            petPanel.hide()
        } else {
            enterIdleMode()
        }
        menuBar.reloadMenu()
    }

    func setShowPico(_ show: Bool) {
        UserDefaults.standard.set(show, forKey: PreferenceKey.showPico)
        updatePetVisibility()
        if show && !isPaused {
            startGhostModeIfNeeded()
            director.start()
        } else {
            ghostModeMonitor.stop()
            director.stop()
        }
    }

    func setGhostModeEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: PreferenceKey.ghostModeEnabled)
        syncGhostModeEnabled()
        if enabled, !isPaused {
            startGhostModeIfNeeded()
        }
    }

    private func syncGhostModeEnabled() {
        let enabled = UserDefaults.standard.object(forKey: PreferenceKey.ghostModeEnabled) as? Bool ?? true
        ghostModeMonitor.setEnabled(enabled)
        if !enabled {
            petPanel.setGhosted(false, animated: false)
        }
    }

    private func startGhostModeIfNeeded() {
        let enabled = UserDefaults.standard.object(forKey: PreferenceKey.ghostModeEnabled) as? Bool ?? true
        guard enabled, !isPaused else {
            ghostModeMonitor.stop()
            return
        }
        ghostModeMonitor.start()
    }

    func clearHistory() {
        try? environment.conversationStore.clearAll()
        historyViewModel?.reload()
    }

    func quit() {
        environment.hotkeyManager.unregister()
        NSApp.terminate(nil)
    }

    func setPetState(_ state: PetState, force: Bool = false, hold: Bool = false) {
        let resolved = PetStateMachine.resolve(current: petState, requested: state, force: force)
        guard resolved != petState || force else { return }
        successResetTask?.cancel()
        petState = resolved
        petPanel.refreshContent()
        if resolved.isTransient && !hold {
            let delay: UInt64 = resolved == .celebrating ? 1_200_000_000 : 900_000_000
            successResetTask = Task {
                try? await Task.sleep(nanoseconds: delay)
                if !Task.isCancelled, self.petState == resolved {
                    self.petState = .idle
                    self.petPanel.refreshContent()
                }
            }
        }
    }

    private func applySessionPetState(_ state: PetState) {
        director.noteSessionPose(state)
        setPetState(state, hold: state == .curious)
        guard director.currentSettings().sessionBubbles else { return }
        let persona = director.currentSettings().persona
        switch state {
        case .success, .celebrating:
            petPanel.showSpeech(text: PetSpeechLines.line(for: .success, persona: persona))
        case .error:
            petPanel.showSpeech(text: PetSpeechLines.line(for: .error, persona: persona))
        default:
            break
        }
    }

    func showPetSpeech(_ kind: PetSpeechKind) {
        let line = PetSpeechLines.line(for: kind, persona: director.currentSettings().persona)
        petPanel.showSpeech(text: line)
    }

    var canDropToys: Bool { !isPaused && director.allowsToys }

    func handleAskFromPet() {
        guard !isPaused else { return }
        showAssistant(fromPet: true)
    }

    func handlePetGesture() {
        guard !isPaused else { return }
        guard canPlayAmbientGesture else { return }
        director.interact(.pet)
        director.playGreetingIfNeeded()
        setPetState(.love, force: true)
        showPetSpeech(.pet)
    }

    func handleFeedGesture() {
        guard !isPaused else { return }
        guard canPlayAmbientGesture else { return }
        director.interact(.feed)
        director.playFeed()
        setPetState(.celebrating, force: true)
        showPetSpeech(.feed)
    }

    func handleShooGesture() {
        guard !isPaused else { return }
        guard canPlayAmbientGesture else { return }
        director.interact(.shoo)
        director.playShoo()
        setPetState(.sad, force: true)
        showPetSpeech(.shoo)
        petPanel.dashToRandomNearbySpot(animated: true)
    }

    func handlePetDragEnded() {
        director.interact(.drag)
    }

    func handlePetHover() {
        director.interact(.hover)
    }

    func dropToy(_ kind: PetToyKind) {
        director.dropToy(kind)
    }

    func clearToys() {
        director.clearToys()
    }

    func petSettings() -> PetStoredSettings {
        director.currentSettings()
    }

    func savePetSettings(_ settings: PetStoredSettings) {
        director.updateSettings(settings)
    }

    func resetPetCare() { director.resetCare() }
    func resetPetProgression() { director.resetProgression() }
    func resetPetUsage() { director.resetUsage() }

    func showPetTips() {
        if tipsPanel == nil {
            let panel = FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
                styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel]
            )
            panel.title = "Pet tips"
            panel.allowsKeyFocus = true
            tipsPanel = panel
        }
        tipsPanel?.setSwiftUIContent(
            PetTipsView { [weak self] in
                self?.completePetTips()
            }
        )
        tipsPanel?.center()
        tipsPanel?.makeKeyAndOrderFrontActivating()
    }

    private func maybeShowPetTips() {
        guard UserDefaults.standard.bool(forKey: PreferenceKey.hasCompletedOnboarding) else { return }
        guard !UserDefaults.standard.bool(forKey: PreferenceKey.hasSeenPetTips) else { return }
        showPetTips()
    }

    private func completePetTips() {
        UserDefaults.standard.set(true, forKey: PreferenceKey.hasSeenPetTips)
        tipsPanel?.orderOut(nil)
    }

    private func wirePetDirector() {
        petPanel.onDismissToast = { [weak self] in
            self?.director.dismissToast()
        }
        petPanel.onGreeting = { [weak self] in
            guard let self else { return }
            let line = PetSpeechLines.line(for: .greeting, persona: self.director.currentSettings().persona)
            self.petPanel.showSpeech(text: line)
            self.director.playGreetingIfNeeded()
        }
        director.onApplyState = { [weak self] state in
            self?.setPetState(state, hold: true)
        }
        director.onSpeech = { [weak self] text in
            self?.petPanel.showSpeech(text: text)
        }
        director.onMove = { [weak self] origin, animated in
            self?.petPanel.movePetFace(to: origin, animated: animated)
        }
        director.onToys = { [weak self] toys in
            self?.petPanel.syncToys(toys)
        }
        director.onVisual = { [weak self] visual in
            self?.petPanel.applyVisual(visual)
        }
        director.onSnapshot = { [weak self] stats, trait, progression in
            self?.careStats = stats
            self?.usageTrait = trait
            self?.progression = progression
        }
        director.origin = { [weak self] in
            self?.petPanel.petFaceFrame?.origin
        }
        director.visibleFrame = { [weak self] in
            if let frame = self?.petPanel.petFaceFrame,
               let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) {
                return screen.visibleFrame
            }
            return ScreenManager.primaryScreen.visibleFrame
        }
        director.isDragging = { [weak self] in
            self?.petPanel.isDragging ?? false
        }
        director.isSessionBusy = { [weak self] in
            self?.aiSessionActive ?? false
        }
        director.isPaused = { [weak self] in
            self?.isPaused ?? true
        }
    }

    private var canPlayAmbientGesture: Bool {
        !aiSessionActive
    }

    private func updatePetVisibility() {
        let show = UserDefaults.standard.object(forKey: PreferenceKey.showPico) as? Bool ?? true
        if show && !isPaused {
            petPanel.show()
        } else {
            petPanel.hide()
        }
    }

    private func assistantSize() -> CGSize {
        let defaults = UserDefaults.standard
        let width = defaults.object(forKey: PreferenceKey.assistantWidth) as? Double
            ?? PicoTheme.assistantDefaultWidth
        let height = defaults.object(forKey: PreferenceKey.assistantHeight) as? Double
            ?? PicoTheme.assistantDefaultHeight
        return CGSize(width: width, height: height)
    }

    /// Prefer opening Ask/History near the mascot so surfaces feel attached to Pico.
    private func panelOriginNearPet(size: CGSize) -> CGPoint {
        let fallbackScreen = ScreenManager.screenContainingFrontmostApp()
        guard let petFrame = petPanel.petFaceFrame ?? petPanel.frame else {
            return CGPoint(
                x: fallbackScreen.visibleFrame.midX - size.width / 2,
                y: fallbackScreen.visibleFrame.midY - size.height / 2
            )
        }

        let petScreen = NSScreen.screens.first(where: { $0.frame.intersects(petFrame) }) ?? fallbackScreen
        let visible = petScreen.visibleFrame
        var origin = CGPoint(
            x: petFrame.midX - size.width / 2,
            y: petFrame.maxY + PicoTheme.panelGap
        )
        if origin.y + size.height > visible.maxY - PicoTheme.screenMargin {
            origin.y = petFrame.minY - size.height - PicoTheme.panelGap
        }
        origin.x = min(
            max(origin.x, visible.minX + PicoTheme.screenMargin),
            visible.maxX - size.width - PicoTheme.screenMargin
        )
        origin.y = min(
            max(origin.y, visible.minY + PicoTheme.screenMargin),
            visible.maxY - size.height - PicoTheme.screenMargin
        )
        return origin
    }

    private func positionTextPanel(_ panel: FloatingPanel) {
        let screen = ScreenManager.screenContainingFrontmostApp()
        let size = NSSize(width: 320, height: 300)
        let visible = screen.visibleFrame
        var origin = CGPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        if let rect = textViewModel?.selectionRect, rect.width > 0 {
            origin = CGPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 8)
        }
        origin = ScreenManager.clampOrigin(origin, size: size, on: screen)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func repositionTextPanelIfNeeded() {
        guard let textPanel else { return }
        positionTextPanel(textPanel)
    }
}
