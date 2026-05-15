import AppKit
import Foundation
import UniformTypeIdentifiers

enum ClipboardPasteboardRestorer {
    static func restore(item: ClipboardItemRecord, payloadsRoot: URL) throws {
        let folder = payloadsRoot.appendingPathComponent(item.payloadPath, isDirectory: true)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        let raw = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode([String: String].self, from: raw)

        let pb = NSPasteboard.general
        pb.clearContents()

        for (uti, fileName) in manifest {
            guard fileName != "manifest.json" else { continue }
            let url = folder.appendingPathComponent(fileName)
            let data = try Data(contentsOf: url)

            let type = NSPasteboard.PasteboardType(uti)
            pb.setData(data, forType: type)
        }
    }
}
