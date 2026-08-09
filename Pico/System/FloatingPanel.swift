import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onResizeEnd: ((CGSize) -> Void)?

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask = [.nonactivatingPanel, .borderless, .resizable, .fullSizeContentView],
        backing: NSWindow.BackingStoreType = .buffered,
        defer flag: Bool = false
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backing, defer: flag)
        self.delegate = self
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    func setSwiftUIContent<Content: View>(_ view: Content) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    func makeKeyAndOrderFrontActivating() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
}

extension FloatingPanel: NSWindowDelegate {
    func windowDidEndLiveResize(_ notification: Notification) {
        onResizeEnd?(frame.size)
    }
}
