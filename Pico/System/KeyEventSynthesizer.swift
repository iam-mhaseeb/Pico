import AppKit
import Carbon
import CoreGraphics
import Foundation

@MainActor
protocol KeyEventSynthesizing {
    func copy()
    func paste()
}

enum KeyEventSynthesizer {
    static func copy() {
        postCommandKey(keyCode: UInt16(kVK_ANSI_C))
    }

    static func paste() {
        postCommandKey(keyCode: UInt16(kVK_ANSI_V))
    }

    private static func postCommandKey(keyCode: UInt16) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

struct SystemKeyEventSynthesizer: KeyEventSynthesizing {
    func copy() { KeyEventSynthesizer.copy() }
    func paste() { KeyEventSynthesizer.paste() }
}
