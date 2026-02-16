import Cocoa
import Carbon
import os

final class HotkeyManager {

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTrigger: (() -> Void)?
    private let logger = Logger(subsystem: "com.lekito.screengif", category: "HotkeyManager")

    init() {}

    func register(handler: @escaping () -> Void) {
        unregister()
        self.onTrigger = handler

        // ⌘⇧6
        // Virtual Key Code for '6' is 0x16 (22)
        let keyCode: UInt32 = 0x16
        
        // Modifiers: cmdKey | shiftKey
        let modifiers = UInt32(cmdKey | shiftKey)

        let signature = OSType(0x53474946) // "SGIF"
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        
        if status != noErr {
            logger.error("Failed to register global hotkey: \(status)")
            return
        }
        self.hotKeyRef = ref

        // Install Event Handler
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            GlobalHotkeyHandler,
            1,
            &eventSpec,
            selfPtr,
            &eventHandler
        )
        
        logger.info("Global hotkey registered using Carbon: ⌘⇧6")
    }

    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    fileprivate func trigger() {
        onTrigger?()
    }
    
    deinit {
        unregister()
    }
}

// Global C-function callback for Carbon events
private func GlobalHotkeyHandler(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return noErr }
    
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    
    Task { @MainActor in
        manager.trigger()
    }
    
    return noErr
}
