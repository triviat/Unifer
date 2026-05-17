import AppKit
import Foundation

enum ClipboardItemPreview {
    static func primaryTitle(for item: ClipboardItemRecord) -> String {
        if let name = headerTitle(for: item) {
            return name
        }

        if let url = linkURL(for: item) {
            return url.host?.replacingOccurrences(of: "www.", with: "") ?? "Link"
        }

        switch item.primaryKind {
        case ClipboardPrimaryKind.text.rawValue: return "Text"
        case ClipboardPrimaryKind.url.rawValue: return "Link"
        case ClipboardPrimaryKind.image.rawValue: return "Image"
        case ClipboardPrimaryKind.html.rawValue: return "Rich Text"
        case ClipboardPrimaryKind.file.rawValue: return "Files"
        default: return "Clip"
        }
    }

    static func image(for item: ClipboardItemRecord, payloadsRoot: URL) -> NSImage? {
        let folder = payloadsRoot.appendingPathComponent(item.payloadPath, isDirectory: true)

        for name in preferredImageFileNames(manifestIn: folder) {
            let url = folder.appendingPathComponent(name)
            if let image = loadImage(from: url) { return image }
        }

        if let manifest = loadManifest(folder: folder) {
            for fileName in manifest.values.sorted() {
                guard isImageFileName(fileName) else { continue }
                let url = folder.appendingPathComponent(fileName)
                if let image = loadImage(from: url) { return image }
            }
        }

        if let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for url in urls where isImageFileName(url.lastPathComponent) {
                if let image = loadImage(from: url) { return image }
            }
        }

        return nil
    }

    static func isImage(_ item: ClipboardItemRecord, payloadsRoot: URL) -> Bool {
        if item.primaryKind == ClipboardPrimaryKind.image.rawValue { return true }
        if remoteImageURL(for: item, payloadsRoot: payloadsRoot) != nil { return true }
        return image(for: item, payloadsRoot: payloadsRoot) != nil
    }

    static func bodyText(for item: ClipboardItemRecord) -> String? {
        if let t = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return String(t.prefix(500))
        }
        return nil
    }

    static func headerTitle(for item: ClipboardItemRecord) -> String? {
        if let name = item.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return nil
    }

    static func remoteImageURL(for item: ClipboardItemRecord, payloadsRoot: URL) -> URL? {
        if let direct = imageURL(from: item.plainText) {
            return direct
        }

        let folder = payloadsRoot.appendingPathComponent(item.payloadPath, isDirectory: true)
        let htmlURL = folder.appendingPathComponent("body.html")
        guard let data = try? Data(contentsOf: htmlURL),
              let html = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return firstImageURL(inHTML: html)
    }

    static func linkURL(for item: ClipboardItemRecord) -> URL? {
        guard let raw = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return url
    }

    private static func preferredImageFileNames(manifestIn folder: URL) -> [String] {
        ["image.png", "image.tiff", "preview.png", "preview.tiff"]
    }

    private static func isImageFileName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix(".png") || lower.hasSuffix(".tiff") || lower.hasSuffix(".tif")
            || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".gif")
            || lower.contains("image")
    }

    private static func loadManifest(folder: URL) -> [String: String]? {
        let url = folder.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    private static func loadImage(from url: URL) -> NSImage? {
        if let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data) {
            let image = NSImage(size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
            image.addRepresentation(rep)
            return image
        }
        return NSImage(contentsOf: url)
    }

    private static func imageURL(from raw: String?) -> URL? {
        guard let raw else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              isLikelyImageURL(url)
        else {
            return nil
        }
        return url
    }

    private static func firstImageURL(inHTML html: String) -> URL? {
        let pattern = "<img[^>]+src=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let srcRange = Range(match.range(at: 1), in: html)
        else {
            return nil
        }
        return imageURL(from: String(html[srcRange]))
    }

    private static func isLikelyImageURL(_ url: URL) -> Bool {
        let lower = url.absoluteString.lowercased()
        return lower.hasSuffix(".png")
            || lower.hasSuffix(".jpg")
            || lower.hasSuffix(".jpeg")
            || lower.hasSuffix(".gif")
            || lower.hasSuffix(".webp")
            || lower.hasSuffix(".tiff")
            || lower.hasSuffix(".tif")
            || lower.contains("format=png")
            || lower.contains("format=jpg")
            || lower.contains("format=jpeg")
            || lower.contains("format=webp")
    }
}
