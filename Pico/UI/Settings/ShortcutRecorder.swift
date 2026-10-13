import AppKit
import Carbon
import SwiftUI

@MainActor
final class ShortcutCapture: ObservableObject {
    @Published var recording = false
    var onCapture: (HotkeyChord) -> Void = { _ in }
    private var monitor: Any?

    func begin() {
        stop()
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
            return nil
        }
    }

    func stop() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stop()
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifier = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)
        guard hasModifier else { return }
        let carbon = HotkeyChord.carbonModifiers(from: flags.rawValue)
        let next = HotkeyChord(
            keyCode: event.keyCode,
            modifiers: carbon,
            label: HotkeyChord.label(
                keyCode: event.keyCode,
                modifiers: carbon,
                characters: event.charactersIgnoringModifiers
            )
        )
        onCapture(next)
        stop()
    }
}

struct ShortcutRecorder: View {
    let title: String
    @Binding var chord: HotkeyChord
    var onCommit: (HotkeyChord) -> Void

    @StateObject private var capture = ShortcutCapture()

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(capture.recording ? "Press a shortcut…" : chord.label) {
                capture.onCapture = { next in
                    chord = next
                    onCommit(next)
                }
                capture.begin()
            }
        }
        .onDisappear { capture.stop() }
    }
}
