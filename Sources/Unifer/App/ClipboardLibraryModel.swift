import Combine
import SwiftUI
import Foundation
import GRDB

@MainActor
final class ClipboardLibraryModel: ObservableObject {
    @Published var items: [ClipboardItemRecord] = []
    @Published var searchQuery: String = ""
    @Published var collections: [CollectionRecord] = []
    @Published var selectedCollectionId: Int64?
    @Published var selectedItemIndex: Int = 0

    weak var panelController: ClipboardPanelController?

    private let repository: ClipboardRepository

    init(repository: ClipboardRepository) {
        self.repository = repository
    }

    var displayedItems: [ClipboardItemRecord] {
        guard let cid = selectedCollectionId else { return items }
        return items.filter { $0.collectionId == cid }
    }

    var selectedItem: ClipboardItemRecord? {
        let list = displayedItems
        guard !list.isEmpty, selectedItemIndex >= 0, selectedItemIndex < list.count else { return nil }
        return list[selectedItemIndex]
    }

    func selectCollection(_ collection: CollectionRecord?) {
        selectedCollectionId = collection?.id
        selectedItemIndex = 0
    }

    func refresh(resetSelectionToStart: Bool = false) {
        do {
            collections = try repository.allCollections()
            items = try repository.searchFTS(query: searchQuery)
            if resetSelectionToStart {
                selectedItemIndex = 0
            }
            clampSelection()
        } catch {
            items = []
            selectedItemIndex = 0
        }
    }

    func applySearch(_ text: String) {
        searchQuery = text
        selectedItemIndex = 0
        refresh()
    }

    func moveSelection(delta: Int) {
        let count = displayedItems.count
        guard count > 0 else {
            selectedItemIndex = 0
            return
        }
        selectedItemIndex = min(max(selectedItemIndex + delta, 0), count - 1)
    }

    func clampSelection() {
        let count = displayedItems.count
        if count == 0 {
            selectedItemIndex = 0
        } else if selectedItemIndex >= count {
            selectedItemIndex = count - 1
        }
    }

    func color(for collectionId: Int64?) -> Color? {
        guard let collectionId,
              let col = collections.first(where: { $0.id == collectionId })
        else { return nil }
        return color(for: col)
    }

    func color(for collection: CollectionRecord) -> Color {
        if let hex = collection.colorHex {
            return CollectionColor.color(forHex: hex)
        }
        return CollectionColor.color(forHex: CollectionColor.defaultHex(for: collection.sortOrder))
    }

    func color(for item: ClipboardItemRecord) -> Color? {
        color(for: item.collectionId)
    }

    func createCollection() {
        let index = collections.count
        let name = "Folder \(index + 1)"
        let hex = CollectionColor.defaultHex(for: index)
        do {
            _ = try repository.createCollection(name: name, colorHex: hex)
            refresh()
        } catch {}
    }

    func renameCollection(_ collection: CollectionRecord, to name: String) {
        guard let id = collection.id else { return }
        do {
            try repository.updateCollection(id: id, name: name, colorHex: nil)
            refresh()
        } catch {}
    }

    func deleteCollection(_ collection: CollectionRecord) {
        guard let id = collection.id else { return }
        do {
            try repository.deleteCollection(id: id)
            if selectedCollectionId == id {
                selectedCollectionId = nil
            }
            refresh()
        } catch {}
    }

    func renameItem(_ item: ClipboardItemRecord, to name: String) {
        guard let id = item.id else { return }
        do {
            try repository.setItemDisplayName(id: id, displayName: name)
            refresh()
        } catch {}
    }

    func setCollectionColor(_ collection: CollectionRecord, hex: String) {
        guard let id = collection.id else { return }
        do {
            try repository.updateCollection(id: id, name: nil, colorHex: hex)
            refresh()
        } catch {}
    }

    func assignItem(_ item: ClipboardItemRecord, to collection: CollectionRecord?) {
        guard let itemId = item.id else { return }
        do {
            try repository.assignItem(itemId: itemId, collectionId: collection?.id)
            refresh()
        } catch {}
    }

    func pasteSelected() {
        guard let item = selectedItem else { return }
        paste(item: item)
    }

    func paste(item: ClipboardItemRecord) {
        guard let panelController else { return }
        do {
            if let id = item.id {
                try repository.markItemUsed(id: id)
            }
            try ClipboardPasteCoordinator.paste(
                item: item,
                payloadsRoot: payloadsRoot(),
                targetApp: panelController.pasteTargetApp,
                dismissPanel: { panelController.hide() }
            )
            refresh(resetSelectionToStart: true)
        } catch {
            NSLog("Unifer: paste failed — \(error.localizedDescription)")
        }
    }

    func togglePin(for item: ClipboardItemRecord) {
        guard let id = item.id else { return }
        do {
            try repository.setPinned(id: id, isPinned: !item.isPinned)
            refresh()
        } catch {}
    }

    func delete(_ item: ClipboardItemRecord) {
        guard let id = item.id else { return }
        do {
            try repository.deleteItem(id: id)
            refresh()
        } catch {}
    }

    func payloadsRoot() -> URL {
        repository.payloadsDirectory()
    }
}
