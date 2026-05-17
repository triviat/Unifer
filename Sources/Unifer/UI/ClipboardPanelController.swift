import AppKit
import SwiftUI

@MainActor
final class ClipboardPanelController: NSObject {
    static let horizontalInset: CGFloat = 12
    static let bottomInset: CGFloat = 12
    static let shelfHeight: CGFloat = 324

    private let library: ClipboardLibraryModel
    private var panel: NSPanel?
    private var hosting: NSHostingController<AnyView>?
    private var globalMouseMonitor: Any?
    private(set) var pasteTargetApp: NSRunningApplication?

    var isVisible: Bool { panel?.isVisible == true }

    init(library: ClipboardLibraryModel) {
        self.library = library
        super.init()
        library.panelController = self
    }

    func capturePasteTarget() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let bundle = Bundle.main.bundleIdentifier
        if app.bundleIdentifier != bundle {
            pasteTargetApp = app
        }
    }

    func toggle() {
        if isVisible {
            hide()
            return
        }
        show()
    }

    func show() {
        if panel == nil {
            buildPanel()
        }
        guard let panel else { return }
        capturePasteTarget()
        positionPanel(panel)
        library.selectedItemIndex = 0
        library.refresh()
        installMonitors()
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        removeMonitors()
        panel?.orderOut(nil)
    }

    private func buildPanel() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: Self.shelfHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.eventHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        let root = ClipboardShelfView()
            .environmentObject(library)

        let hosting = NSHostingController(rootView: AnyView(root))
        hosting.view.autoresizingMask = [.width, .height]
        panel.contentView = hosting.view
        self.hosting = hosting
        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let width = frame.width - Self.horizontalInset * 2
        let rect = NSRect(
            x: frame.minX + Self.horizontalInset,
            y: frame.minY + Self.bottomInset,
            width: width,
            height: Self.shelfHeight
        )
        panel.setFrame(rect, display: true)
        hosting?.view.frame = NSRect(origin: .zero, size: rect.size)
    }

    private func installMonitors() {
        removeMonitors()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.handleClickOutside()
            }
        }
    }

    private func removeMonitors() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func handleClickOutside() {
        guard let panel, panel.isVisible else { return }
        if !panel.frame.contains(NSEvent.mouseLocation) {
            hide()
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }

        if NSApp.modalWindow != nil || isTextInputFocused() {
            return false
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        switch event.keyCode {
        case 53:
            hide()
            return true
        case 123, 126:
            if flags.contains(.shift) {
                library.moveCollectionSelection(delta: -1)
                return true
            }
            library.moveSelection(delta: -1)
            return true
        case 124, 125:
            if flags.contains(.shift) {
                library.moveCollectionSelection(delta: 1)
                return true
            }
            library.moveSelection(delta: 1)
            return true
        case 36, 76:
            library.pasteSelected()
            return true
        case 51:
            return handleSearchDelete(flags: flags, forward: false)
        case 117:
            return handleSearchDelete(flags: flags, forward: true)
        default:
            break
        }

        if shouldAppendToSearch(event), let chars = event.characters {
            library.applySearch(library.searchQuery + chars)
            return true
        }

        return false
    }

    private func handleSearchDelete(flags: NSEvent.ModifierFlags, forward: Bool) -> Bool {
        var query = library.searchQuery
        if flags.contains(.command) {
            query = ""
        } else if flags.contains(.option) {
            query = forward ? SearchQueryEditing.deleteWordForward(query) : SearchQueryEditing.deleteWordBackward(query)
        } else if forward {
            query = SearchQueryEditing.deleteForward(query)
        } else {
            query = SearchQueryEditing.deleteBackward(query)
        }
        library.applySearch(query)
        return true
    }

    private func isTextInputFocused() -> Bool {
        guard let panel, let responder = panel.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }

    private func shouldAppendToSearch(_ event: NSEvent) -> Bool {
        guard let chars = event.characters, !chars.isEmpty else { return false }
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        guard flags.isEmpty else { return false }
        return chars.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0) && $0.value != 127
        }
    }
}

private final class FloatingPanel: NSPanel {
    var eventHandler: ((NSEvent) -> Bool)?

    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        isOpaque = false
        backgroundColor = .clear
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if eventHandler?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}
