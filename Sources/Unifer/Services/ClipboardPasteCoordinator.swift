import AppKit
import Carbon.HIToolbox
import Foundation
import os.log

/// Restores clipboard content, re-activates the target app, injects ⌘V, suppresses re-capture.
enum ClipboardPasteCoordinator {
    private static let log = Logger(subsystem: "com.unifer", category: "paste")
    private static let lock = NSLock()
    private static var ignoreNextClipboardChange = false
    private static var lastPasteAt: TimeInterval = 0

    static func consumeIgnoreNextCapture() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard ignoreNextClipboardChange else { return false }
        ignoreNextClipboardChange = false
        return true
    }

    static func markIgnoreNextCapture() {
        lock.lock()
        ignoreNextClipboardChange = true
        lock.unlock()
    }

    static func shouldThrottlePaste(now: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if now - lastPasteAt < 0.35 {
            return true
        }
        lastPasteAt = now
        return false
    }

    @MainActor
    static func paste(
        item: ClipboardItemRecord,
        payloadsRoot: URL,
        targetApp: NSRunningApplication?,
        dismissPanel: @escaping () -> Void
    ) throws {
        guard !shouldThrottlePaste() else { return }
        markIgnoreNextCapture()
        try ClipboardPasteboardRestorer.restore(item: item, payloadsRoot: payloadsRoot)

        dismissPanel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            if let targetApp {
                targetApp.activate()
            } else {
                NSApp.hide(nil)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if postCommandV() {
                    log.debug("Posted ⌘V")
                } else {
                    log.warning("⌘V injection failed — grant Accessibility for Unifer in System Settings")
                }
            }
        }
    }

    @discardableResult
    private static func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        let keyCode = CGKeyCode(kVK_ANSI_V)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        return true
    }
}
