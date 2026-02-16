import Cocoa
import os

@MainActor
final class HotkeyManager {

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let logger = Logger(subsystem: "com.lekito.screengif", category: "HotkeyManager")

    func register(handler: @escaping @MainActor () -> Void) {
        let targetKeyCode: UInt16 = 22
        let targetModifiers: NSEvent.ModifierFlags = [.command, .shift]

        func matches(_ event: NSEvent) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return event.keyCode == targetKeyCode && flags == targetModifiers
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if matches(event) {
                DispatchQueue.main.async { handler() }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if matches(event) {
                DispatchQueue.main.async { handler() }
                return nil
            }
            return event
        }

        logger.info("Hotkey registered: ⌘⇧6")
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        logger.info("Hotkey unregistered")
    }

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
}
