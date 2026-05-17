import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardShelfView: View {
    @EnvironmentObject private var library: ClipboardLibraryModel
    @State private var dropTargetCollectionId: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            toolbarRow

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 18) {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .frame(height: 242)
                .clipped()
                .onChange(of: library.selectedItemIndex) { _, newIndex in
                    scrollToSelection(proxy: proxy, index: newIndex)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, minHeight: ClipboardPanelController.shelfHeight - 28, maxHeight: ClipboardPanelController.shelfHeight - 28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 28, y: 10)
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
        ZStack {
            HStack(spacing: 14) {
                searchControl

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        collectionChip(
                            title: "Clipboard",
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

                        toolbarIconButton(systemName: "plus") {
                            library.createCollection()
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                toolbarMenu
            }
        }
        .padding(.horizontal, 2)
    }

    private var searchControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(library.searchQuery.isEmpty ? 0.08 : 0.16), in: Circle())

            if !library.searchQuery.isEmpty {
                Text(library.searchQuery)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(library.searchQuery.isEmpty ? 0.04 : 0.10), in: Capsule())
        .animation(.easeOut(duration: 0.16), value: library.searchQuery.isEmpty)
    }

    private var toolbarMenu: some View {
        Menu {
            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Divider()
            Button("Quit Unifer") {
                NSApp.terminate(nil)
            }
        } label: {
            HStack(spacing: 3) {
                Circle().frame(width: 3, height: 3)
                Circle().frame(width: 3, height: 3)
                Circle().frame(width: 3, height: 3)
            }
            .foregroundStyle(Color.white.opacity(0.85))
            .frame(width: 30, height: 26)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func toolbarIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color.white.opacity(0.95))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
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
            if let color {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white.opacity(isSelected ? 0.98 : 0.88))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(chipFill(isSelected: isSelected, color: color, isDropTarget: isDropTarget))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(isDropTarget ? Color.white.opacity(0.55) : .clear, lineWidth: 1))
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
        if isDropTarget { return Color.white.opacity(0.18) }
        if isSelected { return Color.white.opacity(0.14) }
        if let color { return color.opacity(0.18) }
        return Color.white.opacity(0.04)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ClipboardItemPreview.primaryTitle(for: item))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(relativeDateText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                Spacer(minLength: 8)

                sourceIconBadge
            }

            preview
                .frame(width: 182, height: 146)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(12)
        .frame(width: 206, height: 226, alignment: .topLeading)
        .background(tileFill, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .gesture(
            TapGesture(count: 2).onEnded { onPaste() }
                .exclusively(before: TapGesture().onEnded { onSelect() })
        )
        .onDrag { NSItemProvider(object: item.uuid as NSString) }
    }

    private var relativeDateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: item.createdAt, relativeTo: Date())
    }

    private var borderColor: Color {
        if isSelected { return Color.white.opacity(0.7) }
        if let folderColor { return folderColor.opacity(0.4) }
        return Color.white.opacity(0.1)
    }

    private var tileFill: Color {
        if let folderColor { return folderColor.opacity(0.14) }
        return Color(red: 0.11, green: 0.13, blue: 0.22).opacity(0.98)
    }

    @ViewBuilder
    private var preview: some View {
        if let linkURL = ClipboardItemPreview.linkURL(for: item), item.primaryKind == ClipboardPrimaryKind.url.rawValue {
            linkPreview(url: linkURL)
        } else if ClipboardItemPreview.isImage(item, payloadsRoot: payloadsRoot),
                  let img = ClipboardItemPreview.image(for: item, payloadsRoot: payloadsRoot)
        {
            imagePreview(Image(nsImage: img).resizable())
        } else if let remoteURL = ClipboardItemPreview.remoteImageURL(for: item, payloadsRoot: payloadsRoot) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let image):
                    imagePreview(image.resizable())
                case .failure(_):
                    placeholderPreview(systemName: "photo")
                case .empty:
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    placeholderPreview(systemName: "photo")
                }
            }
        } else if let text = ClipboardItemPreview.bodyText(for: item) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.96))
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.black.opacity(0.42))
        } else if item.primaryKind == ClipboardPrimaryKind.image.rawValue {
            placeholderPreview(systemName: "photo")
        } else {
            placeholderPreview(systemName: "doc")
        }
    }

    private var sourceIconBadge: some View {
        ZStack {
            if let image = sourceAppIcon {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
            } else {
                Image(systemName: item.primaryKind == ClipboardPrimaryKind.url.rawValue ? "link" : "app.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.95),
                                        Color.blue.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .frame(width: 38, height: 38)
    }

    private var sourceAppIcon: NSImage? {
        guard let bundleId = item.sourceBundleId,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        else {
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: appURL.path)
        image.size = NSSize(width: 20, height: 20)
        return image
    }

    @ViewBuilder
    private func imagePreview(_ image: Image) -> some View {
        image
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(10)
            .background(Color.black.opacity(0.92))
    }

    @ViewBuilder
    private func placeholderPreview(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.65))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.92))
    }

    @ViewBuilder
    private func linkPreview(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 0)

            HStack {
                Spacer()

                AsyncImage(url: faviconURL(for: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Image(systemName: "globe")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.78))
                    }
                }
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                Spacer()
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(linkTitle(for: url))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(shortURLText(for: url))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.92))
    }

    private func faviconURL(for url: URL) -> URL? {
        guard let host = url.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(host)")
    }

    private func linkTitle(for url: URL) -> String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? "Link"
    }

    private func shortURLText(for url: URL) -> String {
        let host = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        let path = url.path == "/" ? "" : url.path
        let suffix = path.isEmpty ? "" : String(path.prefix(24))
        return host + suffix
    }
}
