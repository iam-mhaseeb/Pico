import AppKit
import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    var petState: PetState = .idle
    var isPaused = false
    var hotkeyRegistrationFailed = false

    private let environment: AppEnvironment
    private let menuBar = MenuBarController()

    private var textPanel: FloatingPanel?
    private var settingsWindow: NSWindow?
    private var onboardingPanel: FloatingPanel?

    private var textViewModel: TextActionMenuViewModel?
    private var successResetTask: Task<Void, Never>?
    private var textActionsTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
        menuBar.attach(coordinator: self)

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
            hotkeyRegistrationFailed = environment.hotkeyManager.registrationFailedText
            setPetState(.idle, force: true)
        } else {
            setPetState(.sleeping, force: true, hold: true)
        }
        menuBar.reloadMenu()
    }

    func showTextActions() {
        guard !isPaused else { return }

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
                onClose: { [weak self] in self?.hideTextPanel() },
                onPreferredSize: { [weak self] size in self?.resizeTextPanel(to: size) }
            )

            let panel = self.textPanel ?? FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 340),
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
            hideTextPanel()
            setPetState(.sleeping, force: true, hold: true)
        } else {
            enterIdleMode()
        }
        menuBar.reloadMenu()
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

    /// Resizes the Text Actions panel for the current phase, keeping its top edge in place.
    private func resizeTextPanel(to size: CGSize) {
        guard let panel = textPanel else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        if let screen = panel.screen {
            frame.origin = ScreenManager.clampOrigin(frame.origin, size: size, on: screen)
        }
        panel.setFrame(frame, display: true, animate: true)
    }

    private func positionTextPanel(_ panel: FloatingPanel) {
        let screen = ScreenManager.screenContainingFrontmostApp()
        let size = NSSize(
            width: TextActionMenu.panelSize(for: textViewModel?.phase ?? .chooseAction).width,
            height: TextActionMenu.panelSize(for: textViewModel?.phase ?? .chooseAction).height
        )
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
