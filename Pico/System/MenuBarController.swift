import AppKit

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private weak var coordinator: AppCoordinator?

    func attach(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "pawprint.fill",
                accessibilityDescription: "Pico"
            )
            button.image?.isTemplate = true
            button.toolTip = "Pico — A little AI buddy"
        }
        item.menu = buildMenu()
        statusItem = item
    }

    func reloadMenu() {
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let paused = coordinator?.isPaused == true

        let ask = menuItem("Ask Pico", action: #selector(ask))
        ask.isEnabled = !paused
        menu.addItem(ask)

        let text = menuItem("Text Actions", action: #selector(textActions))
        text.isEnabled = !paused
        menu.addItem(text)

        menu.addItem(menuItem("History", action: #selector(history)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", action: #selector(settings)))
        menu.addItem(.separator())
        let pauseTitle = paused ? "Resume Pico" : "Pause Pico"
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
