import AppKit
import Foundation

/// Centralized privacy rules for capture (transient/concealed, blacklist, size — size enforced in writer).
struct ClipboardPrivacySettings: Codable, Sendable {
    var blockedBundleIds: Set<String>
    var maxCaptureBytes: Int
    var ignoreTransient: Bool
    var ignoreConcealed: Bool

    static let `default` = ClipboardPrivacySettings(
        blockedBundleIds: [],
        maxCaptureBytes: 25 * 1024 * 1024,
        ignoreTransient: true,
        ignoreConcealed: true
    )
}

enum ClipboardPrivacy {
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private static let settingsKey = "unifer.clipboardPrivacySettings"

    static func loadSettings() -> ClipboardPrivacySettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(ClipboardPrivacySettings.self, from: data)
        else {
            return .default
        }
        var merged = ClipboardPrivacySettings.default
        merged.blockedBundleIds = decoded.blockedBundleIds
        merged.maxCaptureBytes = decoded.maxCaptureBytes
        merged.ignoreTransient = decoded.ignoreTransient
        merged.ignoreConcealed = decoded.ignoreConcealed
        return merged
    }

    static func saveSettings(_ settings: ClipboardPrivacySettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    static func shouldSkipCapture(
        pasteboardTypes types: [NSPasteboard.PasteboardType],
        settings: ClipboardPrivacySettings
    ) -> Bool {
        if settings.ignoreConcealed, types.contains(concealedType) { return true }
        if settings.ignoreTransient, types.contains(transientType) { return true }
        return false
    }

    static func shouldSkipFrontmostApp(bundleId: String?, settings: ClipboardPrivacySettings) -> Bool {
        guard let bundleId else { return false }
        return settings.blockedBundleIds.contains(bundleId)
    }
}
