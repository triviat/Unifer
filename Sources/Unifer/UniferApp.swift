import AppKit
import SwiftUI

@main
struct UniferApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Unifer", systemImage: "doc.on.clipboard") {
            Button("Open shelf") {
                guard let panel = appDelegate.services?.panelController else { return }
                panel.capturePasteTarget()
                panel.show()
            }
            .keyboardShortcut("v", modifiers: [.option, .shift])

            Divider()

            SettingsLink {
                Text("Privacy settings…")
            }

            Divider()

            Button("Quit Unifer") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        Settings {
            PrivacySettingsView()
        }
    }
}
