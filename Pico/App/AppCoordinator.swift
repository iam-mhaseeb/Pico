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
    var canUndoRewrite: Bool { environment.textProcessor.canUndo }

    private let environment: AppEnvironment
    private let menuBar = MenuBarController()

    private enum PopoverContent { case ask, history }
    private var popoverContent: PopoverContent?

    private var textPanel: FloatingPanel?
    private var settingsWindow: NSWindow?
    private var onboardingPanel: FloatingPanel?
    private var confirmPanel: FloatingPanel?
    private var confirmContinuation: CheckedContinuation<Bool, Never>?

    private var assistantViewModel: AssistantViewModel?
    private var textViewModel: TextActionMenuViewModel?
    private var historyViewModel: HistoryViewModel?
    private var successResetTask: Task<Void, Never>?
    private var textActionsTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
        menuBar.attach(coordinator: self)

        environment.screenAgent.hideChrome = { [weak self] in
            self?.menuBar.orderOutPopover()
        }
        environment.screenAgent.restoreChrome = { [weak self] in
            guard self?.popoverContent != nil else { return }
            self?.menuBar.orderFrontPopover()
        }
        environment.screenAgent.confirmAction = { [weak self] summary in
            guard let self else { return false }
            return await self.confirmScreenAction(summary)
        }

        environment.hotkeyManager.onAsk = { [weak self] in
            self?.toggleAssistant()
        }
        environment.hotkeyManager.onTextActions = { [weak self] in
            self?.showTextActions()
        }
    }

    func start() {
        isPaused = UserDefaults.standard.bool(forKey: PreferenceKey.isPaused)
        menuBar.reloadMenu()
        menuBar.setMascot(state: petState, paused: isPaused)

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
            setPetState(.idle, force: true)
        } else {
            setPetState(.sleeping, force: true, hold: true)
        }
        menuBar.reloadMenu()
    }

    func showAssistant(conversation: Conversation? = nil) {
        guard !isPaused else { return }
        hideTextPanel()

        if menuBar.isPopoverShown, popoverContent == .ask, conversation == nil {
            hideAssistant()
            return
        }

        if !menuBar.isPopoverShown {
            environment.screenAgent.rememberTargetApp()
        }

        let viewModel = assistantViewModel ?? AssistantViewModel(
            aiService: environment.aiService,
            store: environment.conversationStore,
            screenAgent: environment.screenAgent
        )
        viewModel.onPetState = { [weak self] state in
            self?.applySessionPetState(state)
        }
        if let conversation {
            viewModel.load(conversation: conversation)
        }
        assistantViewModel = viewModel

        let root = AssistantView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.hideAssistant() },
            onOpenHistory: { [weak self] in self?.showHistory() }
        )
        popoverContent = .ask
        menuBar.present(root)
        setPetState(.listening)
    }

    func toggleAssistant() {
        if menuBar.isPopoverShown {
            hideAssistant()
            if popoverContent == .history {
                menuBar.dismissPopover()
                popoverContent = nil
            }
        } else {
            showAssistant()
        }
    }

    func hideAssistant() {
        // Only cancel in-flight generation — keep multi-turn AI session across panel closes.
        if assistantViewModel?.isSending == true {
            assistantViewModel?.cancel()
        }
        if popoverContent == .ask {
            menuBar.dismissPopover()
            popoverContent = nil
        }
        setPetState(.idle, force: true)
    }

    func popoverWasDismissed() {
        popoverContent = nil
        if assistantViewModel?.isSending == true {
            assistantViewModel?.cancel()
        }
        setPetState(.idle, force: true)
    }

    func undoLastRewrite() {
        guard !isPaused else { return }
        Task {
            try? await environment.textProcessor.undoLast()
        }
    }

    func hotkeysDidChange() {
        guard !isPaused else { return }
        environment.hotkeyManager.register()
        hotkeyAskFailed = environment.hotkeyManager.registrationFailedAsk
        hotkeyTextFailed = environment.hotkeyManager.registrationFailedText
        hotkeyRegistrationFailed = hotkeyAskFailed || hotkeyTextFailed
    }

    func showTextActions() {
        guard !isPaused else { return }
        hideAssistant()
        hideHistory()

        // Abandon any prior text-actions session so clipboard is restored.
        textActionsTask?.cancel()
        textViewModel?.abandon()

        let viewModel = TextActionMenuViewModel(processor: environment.textProcessor)
        viewModel.onPetState = { [weak self] state in
            self?.applySessionPetState(state)
        }
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
            self.repositionTextPanelIfNeeded()
        }
    }

    func hideTextPanel() {
        textActionsTask?.cancel()
        textActionsTask = nil
        textViewModel?.abandon()
        textViewModel = nil
        textPanel?.orderOut(nil)
        setPetState(.idle, force: true)
    }

    func showHistory() {
        let viewModel = historyViewModel ?? HistoryViewModel(store: environment.conversationStore)
        viewModel.reload()
        historyViewModel = viewModel

        let root = HistoryView(
            viewModel: viewModel,
            onSelect: { [weak self] conversation in
                self?.showAssistant(conversation: conversation)
            },
            onClose: { [weak self] in self?.hideHistory() }
        )
        popoverContent = .history
        menuBar.present(root)
    }

    func hideHistory() {
        guard popoverContent == .history else { return }
        menuBar.dismissPopover()
        popoverContent = nil
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
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
            hideAssistant()
            hideTextPanel()
            hideHistory()
            setPetState(.sleeping, force: true, hold: true)
        } else {
            enterIdleMode()
        }
        menuBar.reloadMenu()
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
        refreshMascot()
        if resolved.isTransient && !hold {
            let delay: UInt64 = resolved == .celebrating ? 1_200_000_000 : 900_000_000
            successResetTask = Task {
                try? await Task.sleep(nanoseconds: delay)
                if !Task.isCancelled, self.petState == resolved {
                    self.petState = .idle
                    self.refreshMascot()
                }
            }
        }
    }

    private func applySessionPetState(_ state: PetState) {
        setPetState(state, hold: state == .curious || state == .working)
    }

    private func refreshMascot() {
        menuBar.setMascot(state: petState, paused: isPaused)
    }

    func confirmScreenAction(_ summary: String) async -> Bool {
        await withCheckedContinuation { continuation in
            if let existing = self.confirmContinuation {
                existing.resume(returning: false)
            }
            self.confirmContinuation = continuation
            let panel = self.confirmPanel ?? FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
                styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]
            )
            panel.allowsKeyFocus = true
            panel.onEscape = { [weak self] in self?.finishScreenConfirm(false) }
            panel.setSwiftUIContent(
                ScreenActionConfirmView(
                    summary: summary,
                    onAllow: { [weak self] in self?.finishScreenConfirm(true) },
                    onDeny: { [weak self] in self?.finishScreenConfirm(false) }
                )
            )
            let size = NSSize(width: 380, height: 220)
            let origin = MenuBarPanelPlacement.origin(
                anchor: self.menuBar.anchorScreenRect() ?? CGRect(
                    x: ScreenManager.primaryScreen.visibleFrame.midX,
                    y: ScreenManager.primaryScreen.visibleFrame.maxY,
                    width: 0,
                    height: 0
                ),
                panelSize: size,
                visibleFrame: (self.menuBar.anchorScreenRect().flatMap { anchor in
                    NSScreen.screens.first { $0.frame.intersects(anchor) }?.visibleFrame
                }) ?? ScreenManager.primaryScreen.visibleFrame,
                gap: PicoTheme.panelGap
            )
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
            panel.makeKeyAndOrderFrontActivating()
            self.confirmPanel = panel
        }
    }

    private func finishScreenConfirm(_ allowed: Bool) {
        confirmPanel?.orderOut(nil)
        confirmContinuation?.resume(returning: allowed)
        confirmContinuation = nil
    }

    private func positionTextPanel(_ panel: FloatingPanel) {
        let screen = ScreenManager.screenContainingFrontmostApp()
        let size = NSSize(width: 360, height: 520)
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
