import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private weak var coordinator: AppCoordinator?
    private var shownState: PetState = .idle
    private var pauseAnimation = false
    private let popover = NSPopover()
    private var mascotHost: ClickThroughHostingView<MenuBarMascotLabel>?
    private var closeGeneration = 0
    private var ignoredCloseGeneration = 0

    func attach(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let item = NSStatusBar.system.statusItem(withLength: 32)
        if let button = item.button {
            button.image = nil
            button.imagePosition = .imageOnly
            button.wantsLayer = true
            button.toolTip = "Pico"
            button.setAccessibilityLabel("Pico")
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            let host = ClickThroughHostingView(
                rootView: MenuBarMascotLabel(state: .idle, pauseAnimation: false)
            )
            host.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(host)
            NSLayoutConstraint.activate([
                host.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                host.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                host.widthAnchor.constraint(equalToConstant: MenuBarMascotLabel.side),
                host.heightAnchor.constraint(equalToConstant: MenuBarMascotLabel.side)
            ])
            mascotHost = host
        }
        statusItem = item
    }

    var isPopoverShown: Bool { popover.isShown }

    func present<Content: View>(_ view: Content) {
        let controller = NSHostingController(rootView: view)
        let size = NSSize(width: 400, height: 560)
        controller.preferredContentSize = size
        popover.contentSize = size
        popover.contentViewController = controller
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func dismissPopover() {
        closePopoverWithoutNotifying()
    }

    func orderOutPopover() {
        closePopoverWithoutNotifying()
    }

    private func closePopoverWithoutNotifying() {
        guard popover.isShown else { return }
        ignoredCloseGeneration = closeGeneration + 1
        popover.performClose(nil)
    }

    func orderFrontPopover() {
        guard let button = statusItem?.button, popover.contentViewController != nil else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func reloadMenu() {}

    func setMascot(state: PetState, paused: Bool) {
        shownState = paused ? .sleeping : state
        pauseAnimation = paused
        mascotHost?.rootView = MenuBarMascotLabel(state: shownState, pauseAnimation: pauseAnimation)
        let button = statusItem?.button
        button?.toolTip = paused ? "Pico is paused. Right-click for the menu." : "Pico. Click to ask. Right-click for the menu."
        button?.setAccessibilityLabel("Pico, \(shownState.accessibilityDescription)")
    }

    func anchorScreenRect() -> NSRect? {
        guard let button = statusItem?.button else { return nil }
        return button.window?.convertToScreen(button.bounds)
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            self.closeGeneration += 1
            if self.closeGeneration == self.ignoredCloseGeneration { return }
            self.coordinator?.popoverWasDismissed()
        }
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let right = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if right || coordinator?.isPaused == true {
            showMenu()
        } else {
            coordinator?.toggleAssistant()
        }
    }

    private func showMenu() {
        dismissPopover()
        let menu = buildMenu()
        guard let button = statusItem?.button else { return }
        let point = NSPoint(x: 0, y: button.bounds.minY - 4)
        menu.popUp(positioning: nil, at: point, in: button)
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

        let undo = menuItem("Undo last rewrite", action: #selector(undoRewrite))
        undo.isEnabled = coordinator?.canUndoRewrite == true && paused == false
        menu.addItem(undo)

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
    @objc private func undoRewrite() { coordinator?.undoLastRewrite() }
    @objc private func history() { coordinator?.showHistory() }
    @objc private func settings() { coordinator?.showSettings() }
    @objc private func togglePause() { coordinator?.togglePause() }
    @objc private func quit() { coordinator?.quit() }
}

struct MenuBarMascotLabel: View {
    static let side: CGFloat = 22

    let state: PetState
    var pauseAnimation: Bool

    var body: some View {
        PetFaceView(
            state: state,
            size: Self.side,
            animationInterval: 1.0 / 8.0,
            pauseAnimation: pauseAnimation
        )
        .frame(width: Self.side, height: Self.side)
        .accessibilityHidden(true)
    }
}

@MainActor
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
