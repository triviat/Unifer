import Foundation
import GRDB

/// Persistence and search for clipboard items.
final class ClipboardRepository {
    private let dbQueue: DatabaseQueue
    private let payloadsRoot: URL
    private let defaultTTLDays: Int

    init(dbQueue: DatabaseQueue, applicationSupportDirectory: URL? = nil, defaultTTLDays: Int = 30) throws {
        self.dbQueue = dbQueue
        let base = applicationSupportDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = base.appendingPathComponent("Unifer", isDirectory: true)
        self.payloadsRoot = root.appendingPathComponent("payloads", isDirectory: true)
        self.defaultTTLDays = defaultTTLDays
        try FileManager.default.createDirectory(at: payloadsRoot, withIntermediateDirectories: true)
    }

    func allCollections() throws -> [CollectionRecord] {
        try dbQueue.read { db in
            try CollectionRecord
                .filter(Column("isSystem") == false)
                .order(Column("sortOrder"))
                .fetchAll(db)
        }
    }

    func insertItem(
        uuid: String,
        createdAt: Date,
        isPinned: Bool,
        collectionId: Int64?,
        sourceBundleId: String?,
        sourceAppName: String?,
        primaryKind: ClipboardPrimaryKind,
        displayName: String? = nil,
        plainText: String?,
        bytesSize: Int,
        payloadRelativePath: String,
        typeManifest: [String: String]
    ) throws {
        let manifestData = try JSONEncoder().encode(typeManifest)
        let manifestJSON = String(data: manifestData, encoding: .utf8) ?? "{}"
        var row = ClipboardItemRecord(
            id: nil,
            uuid: uuid,
            createdAt: createdAt,
            modifiedAt: createdAt,
            isPinned: isPinned,
            collectionId: collectionId,
            sourceBundleId: sourceBundleId,
            sourceAppName: sourceAppName,
            primaryKind: primaryKind.rawValue,
            displayName: displayName,
            plainText: plainText,
            bytesSize: bytesSize,
            payloadPath: payloadRelativePath,
            typeManifestJSON: manifestJSON
        )
        try dbQueue.write { db in
            try row.insert(db)
        }
    }

    func payloadsDirectory() -> URL {
        payloadsRoot
    }

    func relativePayloadPath(for uuid: String) -> String {
        "\(uuid).payload"
    }

    func absolutePayloadURL(relativePath: String) -> URL {
        payloadsRoot.appendingPathComponent(relativePath, isDirectory: false)
    }

    /// Recent items for UI (newest first).
    func recentItems(limit: Int = 200) throws -> [ClipboardItemRecord] {
        try dbQueue.read { db in
            try ClipboardItemRecord
                .order(Column("modifiedAt").desc, Column("createdAt").desc, Column("id").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func searchFTS(query: String, limit: Int = 200) throws -> [ClipboardItemRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return try recentItems(limit: limit)
        }
        let like = "%\(escapeLikePattern(trimmed))%"
        return try dbQueue.read { db in
            let pattern = FTS5Pattern(matchingAllPrefixesIn: trimmed) ?? FTS5Pattern(matchingPhrase: trimmed)
            if let pattern {
                return try ClipboardItemRecord.fetchAll(
                    db,
                    sql: """
                    SELECT DISTINCT *
                    FROM clipboard_item
                    WHERE id IN (
                        SELECT rowid
                        FROM clipboard_item_fts
                        WHERE clipboard_item_fts MATCH ?
                    )
                    OR COALESCE(displayName, '') LIKE ? ESCAPE '\\' COLLATE NOCASE
                    OR COALESCE(plainText, '') LIKE ? ESCAPE '\\' COLLATE NOCASE
                    OR COALESCE(sourceAppName, '') LIKE ? ESCAPE '\\' COLLATE NOCASE
                    ORDER BY modifiedAt DESC, createdAt DESC, id DESC
                    LIMIT ?
                    """,
                    arguments: [pattern, like, like, like, limit]
                )
            }
            return try ClipboardItemRecord.fetchAll(
                db,
                sql: """
                SELECT DISTINCT *
                FROM clipboard_item
                WHERE COALESCE(displayName, '') LIKE ? ESCAPE '\\' COLLATE NOCASE
                   OR COALESCE(plainText, '') LIKE ? ESCAPE '\\' COLLATE NOCASE
                   OR COALESCE(sourceAppName, '') LIKE ? ESCAPE '\\' COLLATE NOCASE
                ORDER BY modifiedAt DESC, createdAt DESC, id DESC
                LIMIT ?
                """,
                arguments: [like, like, like, limit]
            )
        }
    }

    /// Delete items older than TTL unless pinned.
    func purgeExpired(referenceDate: Date = Date()) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -defaultTTLDays, to: referenceDate)!
        try dbQueue.write { db in
            let ids: [Int64] = try Int64.fetchAll(
                db,
                sql: """
                SELECT id FROM clipboard_item
                WHERE isPinned = 0 AND createdAt < ?
                """,
                arguments: [cutoff]
            )
            for id in ids {
                if let row = try ClipboardItemRecord.fetchOne(db, key: id) {
                    let url = payloadsRoot.appendingPathComponent(row.payloadPath)
                    try? FileManager.default.removeItem(at: url)
                }
                try ClipboardItemRecord.deleteOne(db, key: id)
            }
        }
    }

    func deleteItem(id: Int64) throws {
        try dbQueue.write { db in
            guard let row = try ClipboardItemRecord.fetchOne(db, key: id) else { return }
            let url = payloadsRoot.appendingPathComponent(row.payloadPath)
            try? FileManager.default.removeItem(at: url)
            try ClipboardItemRecord.deleteOne(db, key: id)
        }
    }

    func setPinned(id: Int64, isPinned: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboard_item SET isPinned = ?, modifiedAt = ? WHERE id = ?",
                arguments: [isPinned, Date(), id]
            )
        }
    }

    func createCollection(name: String, colorHex: String) throws -> CollectionRecord {
        try dbQueue.write { db in
            let maxOrder = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sortOrder), -1) FROM collection") ?? -1
            var row = CollectionRecord(
                id: nil,
                name: name,
                sortOrder: maxOrder + 1,
                isSystem: false,
                colorHex: colorHex
            )
            try row.insert(db)
            return row
        }
    }

    func updateCollection(id: Int64, name: String?, colorHex: String?) throws {
        try dbQueue.write { db in
            if let name {
                try db.execute(sql: "UPDATE collection SET name = ? WHERE id = ?", arguments: [name, id])
            }
            if let colorHex {
                try db.execute(sql: "UPDATE collection SET colorHex = ? WHERE id = ?", arguments: [colorHex, id])
            }
        }
    }

    func assignItem(itemId: Int64, collectionId: Int64?) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboard_item SET collectionId = ?, modifiedAt = ? WHERE id = ?",
                arguments: [collectionId, Date(), itemId]
            )
        }
    }

    func collection(byId id: Int64) throws -> CollectionRecord? {
        try dbQueue.read { db in
            try CollectionRecord.fetchOne(db, key: id)
        }
    }

    func deleteCollection(id: Int64) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboard_item SET collectionId = NULL WHERE collectionId = ?",
                arguments: [id]
            )
            try db.execute(
                sql: "DELETE FROM collection WHERE id = ? AND isSystem = 0",
                arguments: [id]
            )
        }
    }

    func setItemDisplayName(id: Int64, displayName: String?) throws {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty == false) ? trimmed : nil
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboard_item SET displayName = ?, modifiedAt = ? WHERE id = ?",
                arguments: [value, Date(), id]
            )
        }
    }

    func markItemUsed(id: Int64, at date: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE clipboard_item SET modifiedAt = ? WHERE id = ?",
                arguments: [date, id]
            )
        }
    }

    private func escapeLikePattern(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
