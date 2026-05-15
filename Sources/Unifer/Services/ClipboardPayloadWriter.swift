import AppKit
import Foundation
import UniformTypeIdentifiers

/// Serializes `NSPasteboard` contents into a per-item folder under the payloads root.
enum ClipboardPayloadWriter {
    struct Result: Sendable {
        let relativeFolder: String
        let primaryKind: ClipboardPrimaryKind
        let plainText: String?
        let totalBytes: Int
        let typeManifest: [String: String]
    }

    private static let imageTypeKeys: [NSPasteboard.PasteboardType] = [
        .png, .tiff,
        NSPasteboard.PasteboardType(UTType.png.identifier),
        NSPasteboard.PasteboardType(UTType.tiff.identifier),
        NSPasteboard.PasteboardType(UTType.jpeg.identifier),
        NSPasteboard.PasteboardType(UTType.gif.identifier),
        NSPasteboard.PasteboardType(UTType.image.identifier),
        NSPasteboard.PasteboardType("com.apple.tiff"),
        NSPasteboard.PasteboardType("com.compuserve.gif"),
        NSPasteboard.PasteboardType("public.jpeg")
    ]

    static func write(
        pasteboard: NSPasteboard,
        uuid: String,
        payloadsRoot: URL,
        maxTotalBytes: Int
    ) throws -> Result? {
        let types = pasteboard.types ?? []
        guard !types.isEmpty else { return nil }

        let folder = payloadsRoot.appendingPathComponent(uuid, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var manifest: [String: String] = [:]
        var total = 0
        var primary: ClipboardPrimaryKind = .data
        var plainText: String?

        func writeData(_ data: Data, fileName: String, typeKey: String) throws {
            guard !data.isEmpty else { return }
            total += data.count
            guard total <= maxTotalBytes else {
                throw PayloadError.exceedsMaxBytes
            }
            let url = folder.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            manifest[typeKey] = fileName
        }

        let hasImageType = types.contains { type in
            imageTypeKeys.contains(where: { $0.rawValue == type.rawValue })
                || type.rawValue.contains("image")
                || type.rawValue.contains("png")
                || type.rawValue.contains("tiff")
        }

        do {
            let wroteImage = try writeImagePayload(pasteboard: pasteboard, types: types, writeData: writeData)
            if wroteImage || hasImageType {
                primary = .image
            }

            if let s = pasteboard.string(forType: .string) {
                let data = Data(s.utf8)
                try writeData(data, fileName: "plain.txt", typeKey: NSPasteboard.PasteboardType.string.rawValue)
                if plainText == nil { plainText = s }
                if primary == .data { primary = .text }
            }

            if let rtf = pasteboard.data(forType: .rtf) {
                try writeData(rtf, fileName: "body.rtf", typeKey: NSPasteboard.PasteboardType.rtf.rawValue)
                if primary == .data || primary == .text { primary = .rtf }
            }

            if let html = pasteboard.data(forType: .html) {
                try writeData(html, fileName: "body.html", typeKey: NSPasteboard.PasteboardType.html.rawValue)
                if primary == .data || primary == .text { primary = .html }
            }

            if let url = pasteboard.string(forType: .URL), let data = url.data(using: .utf8) {
                try writeData(data, fileName: "link.url", typeKey: NSPasteboard.PasteboardType.URL.rawValue)
                if primary != .image { primary = .url }
                if plainText == nil { plainText = url }
            }

            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let first = urls.first {
                let list = urls.map(\.path).joined(separator: "\n")
                if let data = list.data(using: .utf8) {
                    try writeData(data, fileName: "files.list", typeKey: "NSFilenamesPboardType")
                    if primary == .data || primary == .text { primary = .file }
                    if plainText == nil { plainText = first.path }
                }
            }

            for type in types where manifest[type.rawValue] == nil {
                guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
                if imageTypeKeys.contains(where: { $0.rawValue == type.rawValue })
                    || type.rawValue.contains("image")
                    || type.rawValue.contains("png")
                    || type.rawValue.contains("tiff")
                {
                    continue
                }
                let name = "bin-\(safeFileName(for: type.rawValue))"
                try writeData(data, fileName: name, typeKey: type.rawValue)
                if primary == .data { primary = .data }
            }

            if !wroteImage, let previewURL = remotePreviewURL(
                plainText: plainText,
                htmlData: pasteboard.data(forType: .html)
            ) {
                plainText = previewURL.absoluteString
                primary = .image
            }

        } catch PayloadError.exceedsMaxBytes {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }

        guard !manifest.isEmpty else {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }

        if primary == .image {
            plainText = plainText ?? "Image"
        }

        let manifestURL = folder.appendingPathComponent("manifest.json")
        let manifestBody = try JSONEncoder().encode(manifest)
        try manifestBody.write(to: manifestURL, options: .atomic)

        return Result(
            relativeFolder: uuid,
            primaryKind: primary,
            plainText: plainText,
            totalBytes: total + manifestBody.count,
            typeManifest: manifest
        )
    }

    @discardableResult
    private static func writeImagePayload(
        pasteboard: NSPasteboard,
        types: [NSPasteboard.PasteboardType],
        writeData: (Data, String, String) throws -> Void
    ) throws -> Bool {
        var wrote = false

        if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = objects.first
        {
            wrote = try writeCanonicalImage(image: image, writeData: writeData)
        }

        if !wrote {
            for type in types {
                guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
                let raw = type.rawValue.lowercased()
                guard raw.contains("png") || raw.contains("tiff") || raw.contains("image")
                    || raw.contains("jpeg") || raw.contains("gif")
                else { continue }

                if let image = NSImage(data: data) {
                    wrote = try writeCanonicalImage(image: image, writeData: writeData)
                    if wrote { break }
                }

                let isPng = raw.contains("png")
                let fileName = isPng ? "image.png" : "image.tiff"
                let key = isPng ? NSPasteboard.PasteboardType.png.rawValue : NSPasteboard.PasteboardType.tiff.rawValue
                try writeData(data, fileName, key)
                wrote = true
                break
            }
        }

        if !wrote {
            for type in imageTypeKeys {
                guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
                if let image = NSImage(data: data) {
                    wrote = try writeCanonicalImage(image: image, writeData: writeData)
                    if wrote { break }
                }

                let isPng = type == .png || type.rawValue.localizedCaseInsensitiveContains("png")
                let fileName = isPng ? "image.png" : "image.tiff"
                let key = isPng ? NSPasteboard.PasteboardType.png.rawValue : NSPasteboard.PasteboardType.tiff.rawValue
                try writeData(data, fileName, key)
                wrote = true
                break
            }
        }

        return wrote
    }

    @discardableResult
    private static func writeCanonicalImage(
        image: NSImage,
        writeData: (Data, String, String) throws -> Void
    ) throws -> Bool {
        if let png = pngData(from: image) {
            try writeData(png, "image.png", NSPasteboard.PasteboardType.png.rawValue)
            return true
        }
        if let tiff = image.tiffRepresentation {
            try writeData(tiff, "image.tiff", NSPasteboard.PasteboardType.tiff.rawValue)
            return true
        }
        return false
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static func safeFileName(for raw: String) -> String {
        raw.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .prefix(120)
            .description
    }

    private static func remotePreviewURL(plainText: String?, htmlData: Data?) -> URL? {
        if let plainText,
           let url = URL(string: plainText.trimmingCharacters(in: .whitespacesAndNewlines)),
           isLikelyImageURL(url)
        {
            return url
        }

        guard let htmlData,
              let html = String(data: htmlData, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: "<img[^>]+src=[\"']([^\"']+)[\"']", options: [.caseInsensitive])
        else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let srcRange = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        let rawURL = String(html[srcRange])
        guard let url = URL(string: rawURL), isLikelyImageURL(url) else { return nil }
        return url
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

    private enum PayloadError: Error {
        case exceedsMaxBytes
    }
}
