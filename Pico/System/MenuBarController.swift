import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private weak var coordinator: AppCoordinator?
    private var shownState: PetState = .idle

    func attach(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        let item = NSStatusBar.system.statusItem(withLength: 28)
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.toolTip = "Pico"
            button.setAccessibilityLabel("Pico")
        }
        item.menu = buildMenu()
        statusItem = item
        renderMascot()
    }

    func reloadMenu() {
        statusItem?.menu = buildMenu()
    }

    func setMascot(state: PetState, paused: Bool) {
        shownState = paused ? .sleeping : state
        renderMascot()
        let button = statusItem?.button
        button?.toolTip = paused ? "Pico is paused" : "Pico"
        button?.setAccessibilityLabel("Pico, \(shownState.accessibilityDescription)")
    }

    /// Screen coordinates of the menu-bar icon, used to open panels just beneath it.
    func anchorScreenRect() -> NSRect? {
        guard let button = statusItem?.button else { return nil }
        return button.window?.convertToScreen(button.bounds)
    }

    private func renderMascot() {
        let renderer = ImageRenderer(
            content: MenuBarMascotLabel(state: shownState)
        )
        renderer.scale = statusItem?.button?.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        renderer.proposedSize = ProposedViewSize(
            width: MenuBarMascotLabel.side,
            height: MenuBarMascotLabel.side
        )
        guard let image = renderer.nsImage else { return }
        image.isTemplate = false
        image.size = NSSize(width: MenuBarMascotLabel.side, height: MenuBarMascotLabel.side)
        statusItem?.button?.image = image
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let paused = coordinator?.isPaused == true

        let ask = menuItem("Ask Pico", action: #selector(ask))
        ask.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(ask)

        let text = menuItem("Text Actions", action: #selector(textActions))
        text.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(text)

        menu.addItem(menuItem("History", action: #selector(history)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", action: #selector(settings)))
        menu.addItem(.separator())
        let pauseTitle = PicoMenuLayout.pauseTitle(isPaused: paused)
        menu.addItem(menuItem(pauseTitle, action: #selector(togglePause)))
        menu.addItem(menuItem("Quit Pico", action: #selector(quit)))
        return menu
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func ask() { coordinator?.showAssistant() }
    @objc private func textActions() { coordinator?.showTextActions() }
    @objc private func history() { coordinator?.showHistory() }
    @objc private func settings() { coordinator?.showSettings() }
    @objc private func togglePause() { coordinator?.togglePause() }
    @objc private func quit() { coordinator?.quit() }
}

struct MenuBarMascotLabel: View {
    static let side: CGFloat = 18

    let state: PetState

    var body: some View {
        PetFaceView(state: state, size: Self.side, pauseAnimation: true)
            .frame(width: Self.side, height: Self.side)
    }
}
