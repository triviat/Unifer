import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardWatcher: ObservableObject {
    @Published private(set) var lastCapturedAt: Date?
    @Published private(set) var lastErrorDescription: String?

    private var timer: Timer?
    private var privacyObserver: NSObjectProtocol?
    private var lastChangeCount: Int = -1
    private let repository: ClipboardRepository
    private var settings: ClipboardPrivacySettings

    init(repository: ClipboardRepository) {
        self.repository = repository
        self.settings = ClipboardPrivacy.loadSettings()
    }

    func reloadPrivacySettings() {
        settings = ClipboardPrivacy.loadSettings()
    }

    func start() {
        timer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount
        privacyObserver = NotificationCenter.default.addObserver(
            forName: .uniferPrivacySettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadPrivacySettings()
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let privacyObserver {
            NotificationCenter.default.removeObserver(privacyObserver)
            self.privacyObserver = nil
        }
    }

    private func poll() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        captureAndPersist(pasteboard: pb)
    }

    private func captureAndPersist(pasteboard: NSPasteboard) {
        if ClipboardPasteCoordinator.consumeIgnoreNextCapture() {
            lastChangeCount = pasteboard.changeCount
            return
        }
        reloadPrivacySettings()
        let types = pasteboard.types ?? []
        if ClipboardPrivacy.shouldSkipCapture(pasteboardTypes: types, settings: settings) {
            return
        }
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if ClipboardPrivacy.shouldSkipFrontmostApp(bundleId: bundleId, settings: settings) {
            return
        }

        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        let uuid = UUID().uuidString

        do {
            let root = repository.payloadsDirectory()
            guard let written = try ClipboardPayloadWriter.write(
                pasteboard: pasteboard,
                uuid: uuid,
                payloadsRoot: root,
                maxTotalBytes: settings.maxCaptureBytes
            ) else {
                return
            }

            try repository.insertItem(
                uuid: uuid,
                createdAt: Date(),
                isPinned: false,
                collectionId: nil,
                sourceBundleId: bundleId,
                sourceAppName: appName,
                primaryKind: written.primaryKind,
                plainText: written.plainText,
                bytesSize: written.totalBytes,
                payloadRelativePath: written.relativeFolder,
                typeManifest: written.typeManifest
            )
            try repository.purgeExpired()
            lastCapturedAt = Date()
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }
}
