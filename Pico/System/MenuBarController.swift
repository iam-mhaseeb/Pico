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

        let pet = menuItem("Pet Pico", action: #selector(petPico))
        pet.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(pet)
        let feed = menuItem("Feed Pico", action: #selector(feedPico))
        feed.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(feed)
        let shoo = menuItem("Shoo Pico", action: #selector(shooPico))
        shoo.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        menu.addItem(shoo)

        let toys = NSMenu()
        for kind in PetToyKind.allCases {
            let item = NSMenuItem(title: kind.title, action: #selector(dropToy(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = kind.rawValue
            item.isEnabled = coordinator?.canDropToys == true
            toys.addItem(item)
        }
        toys.addItem(.separator())
        let clear = NSMenuItem(title: "Clear toys", action: #selector(clearToys), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = PicoMenuLayout.sessionActionsEnabled(isPaused: paused)
        toys.addItem(clear)
        let toysItem = NSMenuItem(title: "Drop toy", action: nil, keyEquivalent: "")
        toysItem.submenu = toys
        menu.addItem(toysItem)

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
    @objc private func petPico() { coordinator?.handlePetGesture() }
    @objc private func feedPico() { coordinator?.handleFeedGesture() }
    @objc private func shooPico() { coordinator?.handleShooGesture() }
    @objc private func dropToy(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let kind = PetToyKind(rawValue: raw) else { return }
        coordinator?.dropToy(kind)
    }
    @objc private func clearToys() { coordinator?.clearToys() }
    @objc private func settings() { coordinator?.showSettings() }
    @objc private func togglePause() { coordinator?.togglePause() }
    @objc private func quit() { coordinator?.quit() }
}
