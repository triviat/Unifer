import Foundation

enum SearchQueryEditing {
    static func deleteBackward(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return String(text.dropLast())
    }

    static func deleteWordBackward(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = String(text.dropLast())
        while let last = result.unicodeScalars.last, CharacterSet.whitespacesAndNewlines.contains(last) {
            result = String(result.dropLast())
        }
        while let last = result.unicodeScalars.last, !CharacterSet.whitespacesAndNewlines.contains(last) {
            result = String(result.dropLast())
        }
        return result
    }

    static func deleteForward(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return String(text.dropFirst())
    }

    static func deleteWordForward(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = String(text.dropFirst())
        while let first = result.unicodeScalars.first, CharacterSet.whitespacesAndNewlines.contains(first) {
            result = String(result.dropFirst())
        }
        while let first = result.unicodeScalars.first, !CharacterSet.whitespacesAndNewlines.contains(first) {
            result = String(result.dropFirst())
        }
        return result
    }
}
