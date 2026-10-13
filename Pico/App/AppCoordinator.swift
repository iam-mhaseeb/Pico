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

    private let environment: AppEnvironment
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
    private var textActionsTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
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
        hideHistory()

        if assistantPanel?.isVisible == true, conversation == nil {
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

        let size = assistantSize()
        let origin = panelOriginAttachedToMenuBar(size: size)

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
        // Only cancel in-flight generation — keep multi-turn AI session across panel closes.
        if assistantViewModel?.isSending == true {
            assistantViewModel?.cancel()
        }
        assistantPanel?.orderOut(nil)
        setPetState(.idle, force: true)
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
            origin = panelOriginAttachedToMenuBar(size: size)
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
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
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

    private func assistantSize() -> CGSize {
        let defaults = UserDefaults.standard
        let width = defaults.object(forKey: PreferenceKey.assistantWidth) as? Double
            ?? PicoTheme.assistantDefaultWidth
        let height = defaults.object(forKey: PreferenceKey.assistantHeight) as? Double
            ?? PicoTheme.assistantDefaultHeight
        return CGSize(width: width, height: height)
    }

    /// Ask and History open under the menu-bar mascot instead of a desktop overlay.
    private func panelOriginAttachedToMenuBar(size: CGSize) -> CGPoint {
        let fallbackScreen = ScreenManager.screenContainingFrontmostApp()
        guard let anchor = menuBar.anchorScreenRect() else {
            let visible = fallbackScreen.visibleFrame
            return MenuBarPanelPlacement.origin(
                anchor: CGRect(x: visible.midX, y: visible.maxY, width: 0, height: 0),
                panelSize: size,
                visibleFrame: visible,
                gap: PicoTheme.screenMargin
            )
        }
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? fallbackScreen
        return MenuBarPanelPlacement.origin(
            anchor: anchor,
            panelSize: size,
            visibleFrame: screen.visibleFrame,
            gap: PicoTheme.panelGap
        )
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
