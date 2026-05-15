import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardShelfView: View {
    @EnvironmentObject private var library: ClipboardLibraryModel
    @State private var dropTargetCollectionId: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbarRow

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(library.displayedItems.enumerated()), id: \.element.uuid) { index, item in
                            ClipboardItemTile(
                                item: item,
                                payloadsRoot: library.payloadsRoot(),
                                isSelected: index == library.selectedItemIndex,
                                folderColor: library.color(for: item),
                                onPaste: { library.paste(item: item) },
                                onSelect: { library.selectedItemIndex = index }
                            )
                            .id(item.uuid)
                            .contextMenu {
                                Button("Rename…") { promptRenameItem(item) }
                                Button(item.isPinned ? "Unpin" : "Pin") {
                                    library.togglePin(for: item)
                                }
                                Button("Delete", role: .destructive) {
                                    library.delete(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .frame(height: 200)
                .onChange(of: library.selectedItemIndex) { _, newIndex in
                    scrollToSelection(proxy: proxy, index: newIndex)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: ClipboardPanelController.shelfHeight - 28, maxHeight: ClipboardPanelController.shelfHeight - 28)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        )
        .onAppear {
            library.refresh()
        }
    }

    private func scrollToSelection(proxy: ScrollViewProxy, index: Int) {
        let items = library.displayedItems
        guard items.indices.contains(index) else { return }
        proxy.scrollTo(items[index].uuid, anchor: .center)
    }

    private var toolbarRow: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    collectionChip(
                        title: "All",
                        color: nil,
                        isSelected: library.selectedCollectionId == nil,
                        collection: nil
                    )

                    ForEach(Array(library.collections.enumerated()), id: \.offset) { _, col in
                        collectionChip(
                            title: col.name,
                            color: library.color(for: col),
                            isSelected: library.selectedCollectionId == col.id,
                            collection: col
                        )
                    }

                    Button(action: { library.createCollection() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .help("New folder")
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(library.searchQuery.isEmpty ? "Search" : library.searchQuery)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(library.searchQuery.isEmpty ? .secondary : .primary)
                    .frame(width: 140, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: Capsule())
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func collectionChip(
        title: String,
        color: Color?,
        isSelected: Bool,
        collection: CollectionRecord?
    ) -> some View {
        let isDropTarget: Bool = {
            if collection == nil { return dropTargetCollectionId == -1 }
            return dropTargetCollectionId == collection?.id
        }()

        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(chipFill(isSelected: isSelected, color: color, isDropTarget: isDropTarget))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isDropTarget ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(Capsule())
            .onTapGesture {
                library.selectCollection(collection)
            }
            .contextMenu {
                if let collection {
                    Button("Rename…") { promptRenameCollection(collection) }
                    Menu("Color") {
                        ForEach(CollectionColor.palette, id: \.self) { hex in
                            Button {
                                library.setCollectionColor(collection, hex: hex)
                            } label: {
                                Label(CollectionColor.label(for: hex), systemImage: "circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(CollectionColor.color(forHex: hex))
                            }
                        }
                    }
                    Divider()
                    Button("Delete folder", role: .destructive) {
                        library.deleteCollection(collection)
                    }
                }
            }
            .onDrop(of: [.plainText], isTargeted: Binding(
                get: { isDropTarget },
                set: { targeted in
                    if collection == nil {
                        dropTargetCollectionId = targeted ? -1 : nil
                    } else {
                        dropTargetCollectionId = targeted ? collection?.id : nil
                    }
                }
            )) { providers in
                handleDrop(providers: providers, collection: collection)
            }
    }

    private func chipFill(isSelected: Bool, color: Color?, isDropTarget: Bool) -> Color {
        if isDropTarget { return Color.accentColor.opacity(0.35) }
        if isSelected { return (color ?? Color.accentColor).opacity(0.35) }
        if let color { return color.opacity(0.18) }
        return Color.secondary.opacity(0.12)
    }

    private func handleDrop(providers: [NSItemProvider], collection: CollectionRecord?) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let uuid: String?
            if let data = item as? Data {
                uuid = String(data: data, encoding: .utf8)
            } else if let str = item as? String {
                uuid = str
            } else {
                uuid = nil
            }
            guard let uuid else { return }
            Task { @MainActor in
                guard let match = library.items.first(where: { $0.uuid == uuid }) else { return }
                library.assignItem(match, to: collection)
                dropTargetCollectionId = nil
            }
        }
        return true
    }

    private func promptRenameCollection(_ collection: CollectionRecord) {
        let alert = NSAlert()
        alert.messageText = "Rename folder"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: collection.name)
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        library.renameCollection(collection, to: name)
    }

    private func promptRenameItem(_ item: ClipboardItemRecord) {
        let alert = NSAlert()
        alert.messageText = "Rename clip"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: item.displayName ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        library.renameItem(item, to: name)
    }
}

private struct ClipboardItemTile: View {
    let item: ClipboardItemRecord
    let payloadsRoot: URL
    let isSelected: Bool
    let folderColor: Color?
    let onPaste: () -> Void
    let onSelect: () -> Void

    var body: some View {
        let header = ClipboardItemPreview.headerTitle(for: item)

        VStack(alignment: .leading, spacing: 4) {
            if let header {
                Text(header)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            preview
                .frame(width: 148, height: header == nil ? 108 : 88)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(item.sourceAppName ?? "Unknown")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(width: 168, height: header == nil ? 148 : 158, alignment: .topLeading)
        .background(tileFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(borderColor, lineWidth: isSelected ? 3 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .gesture(
            TapGesture(count: 2).onEnded { onPaste() }
                .exclusively(before: TapGesture().onEnded { onSelect() })
        )
        .onDrag { NSItemProvider(object: item.uuid as NSString) }
    }

    private var borderColor: Color {
        if isSelected { return .accentColor }
        if let folderColor { return folderColor.opacity(0.7) }
        return Color.secondary.opacity(0.2)
    }

    private var tileFill: Color {
        if let folderColor { return folderColor.opacity(0.14) }
        return Color(nsColor: .controlBackgroundColor).opacity(0.65)
    }

    @ViewBuilder
    private var preview: some View {
        if ClipboardItemPreview.isImage(item, payloadsRoot: payloadsRoot),
           let img = ClipboardItemPreview.image(for: item, payloadsRoot: payloadsRoot)
        {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: 148, maxHeight: .infinity)
                .clipped()
        } else if let remoteURL = ClipboardItemPreview.remoteImageURL(for: item, payloadsRoot: payloadsRoot) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                        .controlSize(.small)
                @unknown default:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 148, maxHeight: .infinity)
            .clipped()
        } else if let text = ClipboardItemPreview.bodyText(for: item) {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: 148, maxHeight: .infinity, alignment: .topLeading)
        } else if item.primaryKind == ClipboardPrimaryKind.image.rawValue {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(systemName: "doc")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
