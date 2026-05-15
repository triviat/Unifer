import Foundation
import GRDB

enum ClipboardPrimaryKind: String, Codable, Sendable {
    case text
    case rtf
    case html
    case image
    case url
    case file
    case data
}

struct ClipboardItemRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord {
    static let databaseTableName = "clipboard_item"

    var id: Int64?
    var uuid: String
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    var collectionId: Int64?
    var sourceBundleId: String?
    var sourceAppName: String?
    var primaryKind: String
    var displayName: String?
    var plainText: String?
    var bytesSize: Int
    var payloadPath: String
    var typeManifestJSON: String

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct CollectionRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord {
    static let databaseTableName = "collection"

    var id: Int64?
    var name: String
    var sortOrder: Int
    var isSystem: Bool
    var colorHex: String?

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
