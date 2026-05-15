import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var services: AppServices?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            services = try AppServices()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Unifer failed to start"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
}
