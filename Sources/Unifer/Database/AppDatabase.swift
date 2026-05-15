import Foundation
import GRDB

/// Application SQLite database (history, collections, FTS).
enum AppDatabase {
    static func open(at url: URL) throws -> DatabaseQueue {
        var config = Configuration()
        config.foreignKeysEnabled = true
        let dbQueue = try DatabaseQueue(path: url.path, configuration: config)
        try migrator.migrate(dbQueue)
        return dbQueue
    }

    static var defaultURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Unifer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("unifer.sqlite")
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "collection") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("isSystem", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "clipboard_item") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("uuid", .text).notNull().unique()
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("modifiedAt", .datetime).notNull()
                t.column("isPinned", .boolean).notNull().defaults(to: false)
                t.column("collectionId", .integer).references("collection", onDelete: .setNull)
                t.column("sourceBundleId", .text)
                t.column("sourceAppName", .text)
                t.column("primaryKind", .text).notNull()
                t.column("plainText", .text)
                t.column("bytesSize", .integer).notNull().defaults(to: 0)
                t.column("payloadPath", .text).notNull()
                t.column("typeManifestJSON", .text).notNull()
            }

            try db.create(
                virtualTable: "clipboard_item_fts", using: FTS5()
            ) { t in
                t.tokenizer = .porter(wrapping: .unicode61())
                t.synchronize(withTable: "clipboard_item")
                t.column("plainText")
            }
        }

        migrator.registerMigration("v2_collection_color") { db in
            try db.alter(table: "collection") { t in
                t.add(column: "colorHex", .text)
            }
            let colors = CollectionColor.palette
            let rows = try Row.fetchAll(db, sql: "SELECT id FROM collection ORDER BY sortOrder")
            for (index, row) in rows.enumerated() {
                let id: Int64 = row["id"]
                let hex = colors[index % colors.count]
                try db.execute(sql: "UPDATE collection SET colorHex = ? WHERE id = ?", arguments: [hex, id])
            }
        }

        migrator.registerMigration("v3_display_name_remove_inbox") { db in
            try db.alter(table: "clipboard_item") { t in
                t.add(column: "displayName", .text)
            }
            try db.execute(sql: """
                UPDATE clipboard_item SET collectionId = NULL
                WHERE collectionId IN (SELECT id FROM collection WHERE isSystem = 1 OR name = 'Inbox')
                """)
            try db.execute(sql: "DELETE FROM collection WHERE isSystem = 1 OR name = 'Inbox'")
        }

        return migrator
    }
}
