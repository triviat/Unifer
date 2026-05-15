import AppKit
import Combine
import SwiftUI

@MainActor
final class AppServices: ObservableObject {
    let repository: ClipboardRepository
    let watcher: ClipboardWatcher
    let library: ClipboardLibraryModel
    let panelController: ClipboardPanelController
    private let hotkey: GlobalHotkeyService
    private var cancellables = Set<AnyCancellable>()

    init() throws {
        let dbQueue = try AppDatabase.open(at: AppDatabase.defaultURL)
        let repository = try ClipboardRepository(dbQueue: dbQueue)
        self.repository = repository
        self.watcher = ClipboardWatcher(repository: repository)
        self.library = ClipboardLibraryModel(repository: repository)
        self.panelController = ClipboardPanelController(library: library)
        self.hotkey = GlobalHotkeyService()
        hotkey.onHotkey = { [weak self] in
            guard let self else { return }
            if !self.panelController.isVisible {
                self.panelController.capturePasteTarget()
            }
            self.panelController.toggle()
        }
        try hotkey.register()
        watcher.start()
        library.refresh()

        watcher.$lastCapturedAt
            .receive(on: RunLoop.main)
            .sink { [weak library] _ in
                library?.refresh(resetSelectionToStart: true)
            }
            .store(in: &cancellables)
    }
}
