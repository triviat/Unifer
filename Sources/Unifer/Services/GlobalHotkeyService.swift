import AppKit
import Carbon.HIToolbox
import Foundation

/// Registers Option+Shift+V using Carbon `RegisterEventHotKey`.
final class GlobalHotkeyService {
    var onHotkey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature: FourCharCode = 0x554E_4652

    func register() throws {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var handlerRef: EventHandlerRef?
        let callback: EventHandlerUPP = { _, eventRef, userData -> OSStatus in
            guard let userData, let eventRef else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                eventRef,
                UInt32(kEventParamDirectObject),
                UInt32(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr, hotKeyID.signature == service.signature else {
                return OSStatus(eventNotHandledErr)
            }
            DispatchQueue.main.async {
                service.onHotkey?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )
        eventHandler = handlerRef

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let modifiers = UInt32(shiftKey | optionKey)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else {
            unregister()
            throw NSError(domain: "UniferHotkey", code: Int(status), userInfo: nil)
        }
        hotKeyRef = ref
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}
