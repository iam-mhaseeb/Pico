import AppKit
import ObjectiveC
import SwiftUI

@MainActor
final class PetPanelController {
    private static var menuTargetAssociationKey: UInt8 = 0
    private var panel: FloatingPanel?
    private var container: DraggablePetContainer?
    private weak var coordinator: AppCoordinator?

    func attach(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func show() {
        guard let coordinator else { return }
        if panel == nil {
            let origin = restoredOrigin()
            let size = NSSize(width: PicoTheme.petSize, height: PicoTheme.petSize)
            let panel = FloatingPanel(
                contentRect: NSRect(origin: origin, size: size),
                styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]
            )
            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            panel.level = .floating
            panel.hasShadow = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

            let container = DraggablePetContainer(frame: NSRect(origin: .zero, size: size))
            container.autoresizingMask = [.width, .height]
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.clear.cgColor
            container.setRootView(PetView(coordinator: coordinator))
            container.onClick = { [weak coordinator] in
                coordinator?.showAssistant()
            }
            container.onDragEnded = { [weak self] in
                self?.persistPosition()
            }
            container.menuBuilder = { [weak coordinator] in
                Self.makeContextMenu(coordinator: coordinator)
            }
            panel.contentView = container

            self.container = container
            self.panel = panel
        } else {
            refreshContent()
        }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func refreshContent() {
        guard let coordinator, let container else { return }
        container.setRootView(PetView(coordinator: coordinator))
    }

    func persistPosition() {
        guard let panel else { return }
        let origin = panel.frame.origin
        let screen = panel.screen ?? ScreenManager.primaryScreen
        UserDefaults.standard.set(origin.x, forKey: PreferenceKey.petOriginX)
        UserDefaults.standard.set(origin.y, forKey: PreferenceKey.petOriginY)
        UserDefaults.standard.set(
            Int(ScreenManager.displayID(for: screen)),
            forKey: PreferenceKey.petDisplayID
        )
    }

    var frame: NSRect? {
        panel?.frame
    }

    func handleDisplayChange() {
        guard let panel else { return }
        let displayID = UInt32(UserDefaults.standard.integer(forKey: PreferenceKey.petDisplayID))
        if ScreenManager.screen(forDisplayID: displayID) == nil {
            let origin = ScreenManager.defaultPetOrigin(on: ScreenManager.primaryScreen)
            panel.setFrameOrigin(origin)
            persistPosition()
        }
    }

    private func restoredOrigin() -> CGPoint {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PreferenceKey.petOriginX) != nil,
           defaults.object(forKey: PreferenceKey.petOriginY) != nil {
            let displayID = UInt32(defaults.integer(forKey: PreferenceKey.petDisplayID))
            if ScreenManager.screen(forDisplayID: displayID) != nil || displayID == 0 {
                return CGPoint(
                    x: defaults.double(forKey: PreferenceKey.petOriginX),
                    y: defaults.double(forKey: PreferenceKey.petOriginY)
                )
            }
        }
        return ScreenManager.defaultPetOrigin(on: ScreenManager.primaryScreen)
    }

    private static func makeContextMenu(coordinator: AppCoordinator?) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(Self.item("Ask Pico") { coordinator?.showAssistant() })
        menu.addItem(Self.item("History") { coordinator?.showHistory() })
        menu.addItem(Self.item("Settings") { coordinator?.showSettings() })
        menu.addItem(.separator())
        let pauseTitle = (coordinator?.isPaused == true) ? "Resume Pico" : "Pause Pico"
        menu.addItem(Self.item(pauseTitle) { coordinator?.togglePause() })
        menu.addItem(Self.item("Quit Pico") { coordinator?.quit() })
        return menu
    }

    private static func item(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(PetMenuTarget.performAction(_:)), keyEquivalent: "")
        let target = PetMenuTarget(action: action)
        item.target = target
        objc_setAssociatedObject(
            item,
            &menuTargetAssociationKey,
            target,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return item
    }
}

private final class PetMenuTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction(_ sender: Any?) {
        action()
    }
}
