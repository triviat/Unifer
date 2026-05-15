import SwiftUI

struct PrivacySettingsView: View {
    @State private var settings = ClipboardPrivacy.loadSettings()
    @State private var blockedText: String = ""

    var body: some View {
        Form {
            Section("Capture limits") {
                Stepper(value: $settings.maxCaptureBytes, in: 256 * 1024 ... 200 * 1024 * 1024, step: 256 * 1024) {
                    Text("Max capture size: \(settings.maxCaptureBytes / (1024 * 1024)) MB")
                }
            }

            Section("Privacy filters") {
                Toggle("Ignore transient pasteboard items", isOn: $settings.ignoreTransient)
                Toggle("Ignore concealed (password manager) items", isOn: $settings.ignoreConcealed)
            }

            Section("Blocked apps (bundle IDs, one per line)") {
                TextEditor(text: $blockedText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
            }

            Section {
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 420)
        .onAppear {
            blockedText = settings.blockedBundleIds.sorted().joined(separator: "\n")
        }
    }

    private func save() {
        let ids = Set(
            blockedText
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        settings.blockedBundleIds = ids
        ClipboardPrivacy.saveSettings(settings)
        NotificationCenter.default.post(name: .uniferPrivacySettingsChanged, object: nil)
    }
}
