import AppKit
import SwiftUI

enum CollectionColor {
    static let palette: [String] = [
        "#5AC8FA", "#34C759", "#FF9500", "#AF52DE", "#FF2D55", "#64D2FF", "#8E8E93"
    ]

    static let names: [String: String] = [
        "#5AC8FA": "Sky",
        "#34C759": "Green",
        "#FF9500": "Orange",
        "#AF52DE": "Purple",
        "#FF2D55": "Pink",
        "#64D2FF": "Cyan",
        "#8E8E93": "Gray"
    ]

    static func color(forHex hex: String?) -> Color {
        guard let hex, let ns = NSColor(hex: hex) else {
            return Color.secondary.opacity(0.35)
        }
        return Color(nsColor: ns)
    }

    static func label(for hex: String) -> String {
        names[hex] ?? hex
    }

    static func defaultHex(for index: Int) -> String {
        palette[index % palette.count]
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#8E8E93" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
