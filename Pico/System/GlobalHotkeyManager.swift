import AppKit
import Carbon
import Foundation

@MainActor
final class GlobalHotkeyManager {
    enum HotkeyID: UInt32 {
        case ask = 1
        case textActions = 2
    }

    var onAsk: (() -> Void)?
    var onTextActions: (() -> Void)?
    var registrationFailedAsk = false
    var registrationFailedText = false

    private var askHotKeyRef: EventHotKeyRef?
    private var textHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isRegistered = false

    func register() {
        // Always re-attempt so a previous conflict can recover after the other app releases the key.
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            Task { @MainActor in
                manager.handle(hotKeyID: hotKeyID)
            }
            return noErr
        }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
        guard installStatus == noErr else {
            registrationFailedAsk = true
            registrationFailedText = true
            isRegistered = false
            return
        }

        registrationFailedAsk = !registerHotKey(
            id: .ask,
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey),
            ref: &askHotKeyRef
        )
        registrationFailedText = !registerHotKey(
            id: .textActions,
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey | shiftKey),
            ref: &textHotKeyRef
        )
        isRegistered = !registrationFailedAsk || !registrationFailedText
    }

    func unregister() {
        if let askHotKeyRef {
            UnregisterEventHotKey(askHotKeyRef)
            self.askHotKeyRef = nil
        }
        if let textHotKeyRef {
            UnregisterEventHotKey(textHotKeyRef)
            self.textHotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        isRegistered = false
    }

    private func handle(hotKeyID: EventHotKeyID) {
        switch hotKeyID.id {
        case HotkeyID.ask.rawValue:
            onAsk?()
        case HotkeyID.textActions.rawValue:
            onTextActions?()
        default:
            break
        }
    }

    private func registerHotKey(
        id: HotkeyID,
        keyCode: UInt32,
        modifiers: UInt32,
        ref: inout EventHotKeyRef?
    ) -> Bool {
        var hotKeyID = EventHotKeyID(signature: OSType(0x5049434F), id: id.rawValue) // 'PICO'
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        return status == noErr
    }
}
