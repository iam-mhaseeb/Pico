import AppKit
import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    var petState: PetState = .idle
    var isPaused = false
    var hotkeyRegistrationFailed = false

    private let environment: AppEnvironment
    private let petPanel = PetPanelController()
    private let menuBar = MenuBarController()

    private var assistantPanel: FloatingPanel?
    private var textPanel: FloatingPanel?
    private var historyPanel: FloatingPanel?
    private var settingsWindow: NSWindow?
    private var onboardingPanel: FloatingPanel?

    private var assistantViewModel: AssistantViewModel?
    private var textViewModel: TextActionMenuViewModel?
    private var historyViewModel: HistoryViewModel?
    private var successResetTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
        petPanel.attach(coordinator: self)
        menuBar.attach(coordinator: self)

        environment.hotkeyManager.onAsk = { [weak self] in
            self?.toggleAssistant()
        }
        environment.hotkeyManager.onTextActions = { [weak self] in
            self?.showTextActions()
        }

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

        if !UserDefaults.standard.bool(forKey: PreferenceKey.hasCompletedOnboarding) {
            showOnboarding()
        } else {
            enterIdleMode()
        }
    }

    func enterIdleMode() {
        if !isPaused {
            environment.hotkeyManager.register()
            hotkeyRegistrationFailed =
                environment.hotkeyManager.registrationFailedAsk
                || environment.hotkeyManager.registrationFailedText
            updatePetVisibility()
        }
        menuBar.reloadMenu()
    }

    func showAssistant(conversation: Conversation? = nil) {
        guard !isPaused else { return }
        hideTextPanel()
        hideHistory()

        if assistantPanel?.isVisible == true, conversation == nil {
            hideAssistant()
            return
        }

        let viewModel = assistantViewModel ?? AssistantViewModel(
            aiService: environment.aiService,
            store: environment.conversationStore
        )
        viewModel.onPetState = { [weak self] state in
            self?.setPetState(state)
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
        assistantViewModel?.cancel()
        assistantPanel?.orderOut(nil)
        setPetState(.idle)
    }

    func showTextActions() {
        guard !isPaused else { return }
        hideAssistant()
        hideHistory()

        let viewModel = TextActionMenuViewModel(processor: environment.textProcessor)
        viewModel.onPetState = { [weak self] state in
            self?.setPetState(state)
        }
        viewModel.onFinished = { [weak self] in
            self?.hideTextPanel()
        }
        textViewModel = viewModel

        let root = TextActionMenu(
            viewModel: viewModel,
            onClose: { [weak self] in self?.hideTextPanel() }
        )

        let panel = textPanel ?? FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 280),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]
        )
        panel.onEscape = { [weak self] in
            self?.textViewModel?.cancel()
            self?.hideTextPanel()
        }
        panel.setSwiftUIContent(root)
        positionTextPanel(panel)
        panel.makeKeyAndOrderFrontActivating()
        textPanel = panel

        Task {
            await viewModel.prepare()
            self.repositionTextPanelIfNeeded()
        }
    }

    func hideTextPanel() {
        textPanel?.orderOut(nil)
        if petState != .thinking {
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
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
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
            petPanel.hide()
        } else {
            enterIdleMode()
        }
        menuBar.reloadMenu()
    }

    func setShowPico(_ show: Bool) {
        UserDefaults.standard.set(show, forKey: PreferenceKey.showPico)
        updatePetVisibility()
    }

    func clearHistory() {
        try? environment.conversationStore.clearAll()
        historyViewModel?.reload()
    }

    func quit() {
        environment.hotkeyManager.unregister()
        NSApp.terminate(nil)
    }

    func setPetState(_ state: PetState, force: Bool = false) {
        let resolved = PetStateMachine.resolve(current: petState, requested: state, force: force)
        guard resolved != petState || force else { return }
        successResetTask?.cancel()
        petState = resolved
        petPanel.refreshContent()
        if resolved.isTransient {
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
        guard let petFrame = petPanel.frame else {
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
        var origin = CGPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.midY - size.height / 2
        )
        if let rect = textViewModel?.selectionRect, rect.width > 0 {
            origin = CGPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 8)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func repositionTextPanelIfNeeded() {
        guard let textPanel else { return }
        positionTextPanel(textPanel)
    }
}
