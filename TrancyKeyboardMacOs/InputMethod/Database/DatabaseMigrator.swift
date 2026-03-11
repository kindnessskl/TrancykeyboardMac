import Foundation
import SQLite3
import OSLog

class DatabaseMigrator {
    private let logger = Logger(subsystem: "com.trancy.keyboard", category: "migrator")

    static let shared = DatabaseMigrator()
    private init() {}
    
    enum MigrationError: Error {
        case openMainFailed
        case attachPatchFailed
        case executionFailed(String)
        case pathInvalid
    }
    
    func runMigrations(dbPath: String, patchDbPath: String? = nil) {
        var db: OpaquePointer?
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[DatabaseMigrator] Failed to open database at \(dbPath)")
            return
        }
    
        sqlite3_busy_timeout(db, 5000)
        
        defer {
            sqlite3_close(db)
        }
        
//         【临时调试代码】强制将版本设为 5 以确保测试 V6 迁移
//        if true {
//            let currentV = getDatabaseVersion(db: db)
//            if currentV == 10 {
//                print("[DatabaseMigrator] DEBUG: Force resetting version from 10 to 9 for re-migration test.")
//                setDatabaseVersion(9, db: db)
//            }
//        }
        
        var currentVersion = getDatabaseVersion(db: db)
        print("[DatabaseMigrator] Current database version: \(currentVersion)")
        
        if let patch = patchDbPath {
            print("[DatabaseMigrator] Patch path provided: \(patch)")
        } else {
            print("[DatabaseMigrator] Warning: No patch provided for migration.")
        }

        if currentVersion < 2 {
            if let patch = patchDbPath {
                print("[DatabaseMigrator] Upgrading to V2 (Patch Merge)...")
                do {
                    try mergePatchWithConnection(db: db, patchDbPath: patch)
                    currentVersion = 2
                    setDatabaseVersion(2, db: db)
                } catch {
                    print("[DatabaseMigrator] V2 Migration failed: \(error)")
                    return 
                }
            } else {
                print("[DatabaseMigrator] No patch provided, skipping V2 merge.")
                setDatabaseVersion(2, db: db)
                currentVersion = 2
            }
        }

        if currentVersion < 3 {
            print("[DatabaseMigrator] Upgrading to V3 (Phonex Indexing)...")
            do {
                try migrateToV3(db: db)
                setDatabaseVersion(3, db: db)
                print("[DatabaseMigrator] Migration to V3 successful")
                currentVersion = 3
            } catch {
                print("[DatabaseMigrator] V3 Migration failed: \(error)")
            }
        }

        if currentVersion < 4 {
            if let bundlePath = patchDbPath {
                print("[DatabaseMigrator] Upgrading to V4 (Traditional Column)...")
                do {
                    try migrateToV4(db: db, bundleDbPath: bundlePath)
                    setDatabaseVersion(4, db: db)
                    print("[DatabaseMigrator] Migration to V4 successful")
                    currentVersion = 4
                } catch {
                    print("[DatabaseMigrator] V4 Migration failed: \(error)")
                }
            } else {
                print("[DatabaseMigrator] No bundle provided, skipping V4 migration.")
            }
        }

        if currentVersion < 5 {
            print("[DatabaseMigrator] Upgrading to V5 (Composite Indexes)...")
            do {
                try migrateToV5(db: db)
                setDatabaseVersion(5, db: db)
                print("[DatabaseMigrator] Migration to V5 successful")
            } catch {
                print("[DatabaseMigrator] V5 Migration failed: \(error)")
            }
        }
        
        if currentVersion < 6 {
            print("[DatabaseMigrator] Upgrading to V6 (Composite Indexes)...")
            do {
                try migrateToV6(db: db)
                setDatabaseVersion(6, db: db)
                print("[DatabaseMigrator] Migration to V6 successful")
                currentVersion = 6
            } catch {
                print("[DatabaseMigrator] V6 Migration failed: \(error)")
            }
        }
        
        
        if currentVersion < 7 {
            if let bundlePath = patchDbPath {
                logger.info("[DatabaseMigrator] Upgrading to V7 (Merging chunks and sentences from bundle)...")
                do {
                    try migrateToV7(db: db, bundleDbPath: bundlePath)
                    setDatabaseVersion(7, db: db)
                    logger.info("[DatabaseMigrator] Migration to V7 successful")
                    currentVersion = 7
                } catch {
                    logger.info("[DatabaseMigrator] V7 Migration failed: \(error)")
                }
            } else {
                logger.info("[DatabaseMigrator] No bundle provided, skipping V7 migration.")
            }
        }

        if currentVersion < 8 {
            if let bundlePath = patchDbPath {
                logger.info("[DatabaseMigrator] Upgrading to V8 (Merging sub_english_table and prefix_index)...")
                do {
                    try migrateToV8(db: db, bundleDbPath: bundlePath)
                    setDatabaseVersion(8, db: db)
                    logger.info("[DatabaseMigrator] Migration to V8 successful")
                    currentVersion = 8
                } catch {
                    logger.info("[DatabaseMigrator] V8 Migration failed: \(error)")
                }
            } else {
                logger.info("[DatabaseMigrator] No bundle provided, skipping V8 migration.")
            }
        }

        if currentVersion < 9 {
            if let bundlePath = patchDbPath {
                print("[DatabaseMigrator] Upgrading to V9 (Mapping Repair Surgery)...")
                do {
                    try migrateToV9(db: db, bundleDbPath: bundlePath)
                    setDatabaseVersion(9, db: db)
                    print("[DatabaseMigrator] V9 Mapping Repair successful")
                    currentVersion = 9
                } catch {
                    print("[DatabaseMigrator] V9 Migration failed: \(error)")
                }
            }
        }

        if currentVersion < 10 {
            print("[DatabaseMigrator] Upgrading to V10 (Sub English table index)...")
            setDatabaseVersion(10, db: db)
            currentVersion = 10
        }

        if currentVersion < 11 {
            if let bundlePath = patchDbPath {
                print("[DatabaseMigrator] Upgrading to V11 (Frequency Reset)...")
                do {
                    try migrateToV11(db: db, bundleDbPath: bundlePath)
                    setDatabaseVersion(11, db: db)
                    print("[DatabaseMigrator] V11 Frequency Reset successful")
                    currentVersion = 11
                } catch {
                    print("[DatabaseMigrator] V11 Migration failed: \(error)")
                }
            }
        }
    }

    private func migrateToV11(db: OpaquePointer?, bundleDbPath: String) throws {
        let attachSQL = "ATTACH DATABASE '\(bundleDbPath)' AS bundle_db;"
        if let error = execute(sql: attachSQL, db: db) {
            throw MigrationError.executionFailed("ATTACH bundle failed: \(error)")
        }
        defer {
            _ = execute(sql: "DETACH DATABASE bundle_db;", db: db)
        }

        _ = execute(sql: "BEGIN TRANSACTION;", db: db)

        // 1. 重置中文表频率 (基于词条和拼音匹配)
        let resetChineseSQL = """
            UPDATE main.chinese_table
            SET frequency = (
                SELECT frequency FROM bundle_db.chinese_table
                WHERE bundle_db.chinese_table.word = main.chinese_table.word
                AND bundle_db.chinese_table.pinyin = main.chinese_table.pinyin
                LIMIT 1
            )
            WHERE EXISTS (
                SELECT 1 FROM bundle_db.chinese_table
                WHERE bundle_db.chinese_table.word = main.chinese_table.word
                AND bundle_db.chinese_table.pinyin = main.chinese_table.pinyin
            );
        """
        
        // 2. 重置英文表频率 (基于单词、分类和编号匹配)
        let resetEnglishSQL = """
            UPDATE main.english_table
            SET frequency = (
                SELECT frequency FROM bundle_db.english_table
                WHERE bundle_db.english_table.word = main.english_table.word
                AND bundle_db.english_table.type = main.english_table.type
                AND bundle_db.english_table.type_num = main.english_table.type_num
                LIMIT 1
            )
            WHERE EXISTS (
                SELECT 1 FROM bundle_db.english_table
                WHERE bundle_db.english_table.word = main.english_table.word
                AND bundle_db.english_table.type = main.english_table.type
                AND bundle_db.english_table.type_num = main.english_table.type_num
            );
        """

        if let error = execute(sql: resetChineseSQL, db: db) {
            _ = execute(sql: "ROLLBACK;", db: db)
            throw MigrationError.executionFailed("V11 Chinese Reset failed: \(error)")
        }

        if let error = execute(sql: resetEnglishSQL, db: db) {
            _ = execute(sql: "ROLLBACK;", db: db)
            throw MigrationError.executionFailed("V11 English Reset failed: \(error)")
        }

        _ = execute(sql: "COMMIT;", db: db)
        logger.info("V11 Migration: Frequency reset to factory values successfully.")
    }
        
    private func migrateToV9(db: OpaquePointer?, bundleDbPath: String) throws {
        _ = execute(sql: "ALTER TABLE main.english_table ADD COLUMN ipa TEXT;", db: db)

        let attachSQL = "ATTACH DATABASE '\(bundleDbPath)' AS bundle_db;"
        if let error = execute(sql: attachSQL, db: db) {
            throw MigrationError.executionFailed("ATTACH bundle failed: \(error)")
        }
        defer {
            _ = execute(sql: "DETACH DATABASE bundle_db;", db: db)
        }

        _ = execute(sql: "BEGIN TRANSACTION;", db: db)

        let syncIPASQL = """
            UPDATE main.english_table 
            SET ipa = (
                SELECT ipa FROM bundle_db.english_table 
                WHERE bundle_db.english_table.word = main.english_table.word 
                AND bundle_db.english_table.type = main.english_table.type 
                AND bundle_db.english_table.type_num = main.english_table.type_num
                LIMIT 1
            )
            WHERE EXISTS (
                SELECT 1 FROM bundle_db.english_table 
                WHERE bundle_db.english_table.word = main.english_table.word 
                AND bundle_db.english_table.type = main.english_table.type 
                AND bundle_db.english_table.type_num = main.english_table.type_num
                AND bundle_db.english_table.ipa IS NOT NULL
            );
        """
        
        if let error = execute(sql: syncIPASQL, db: db) {
            _ = execute(sql: "ROLLBACK;", db: db)
            throw MigrationError.executionFailed("V9 IPA sync failed: \(error)")
        }

        _ = execute(sql: "COMMIT;", db: db)
        logger.info("V9 Migration: IPA data successfully synchronized from bundle.")
    }
    
    private func migrateToV8(db: OpaquePointer?, bundleDbPath: String) throws {
        let attachSQL = "ATTACH DATABASE '\(bundleDbPath)' AS bundle_db;"
        if let error = execute(sql: attachSQL, db: db) {
            throw MigrationError.executionFailed("ATTACH bundle failed: \(error)")
        }
        defer {
            _ = execute(sql: "DETACH DATABASE bundle_db;", db: db)
        }

        _ = execute(sql: "BEGIN TRANSACTION;", db: db)

        // 1. 创建表结构与新增字段
        
        _ = execute(sql: "DROP TABLE IF EXISTS main.sub_english_table;", db: db)
        _ = execute(sql: "CREATE TABLE main.sub_english_table (id INTEGER PRIMARY KEY AUTOINCREMENT, word TEXT NOT NULL);", db: db)
        _ = execute(sql: "CREATE INDEX IF NOT EXISTS main.sub_english_table ON sub_english_table (word);", db: db)

        _ = execute(sql: "DROP TABLE IF EXISTS main.english_prefix_index;", db: db)
        _ = execute(sql: "CREATE TABLE main.english_prefix_index (prefix TEXT PRIMARY KEY, top_ids TEXT NOT NULL);", db: db)

        // 2. 合并数据
        let mergeSubSQL = "INSERT INTO main.sub_english_table (id, word) SELECT id, word FROM bundle_db.sub_english_table;"
        if let error = execute(sql: mergeSubSQL, db: db) {
            _ = execute(sql: "ROLLBACK;", db: db)
            throw MigrationError.executionFailed("V8 sub_table merge failed: \(error)")
        }

        let mergeIndexSQL = "INSERT INTO main.english_prefix_index (prefix, top_ids) SELECT prefix, top_ids FROM bundle_db.english_prefix_index;"
        if let error = execute(sql: mergeIndexSQL, db: db) {
            _ = execute(sql: "ROLLBACK;", db: db)
            throw MigrationError.executionFailed("V8 prefix_index merge failed: \(error)")
        }

        _ = execute(sql: "COMMIT;", db: db)
        logger.info("V8 Migration: Sub English table and Prefix Index synchronized from master bundle.")
    }
    
    private func migrateToV7(db: OpaquePointer?, bundleDbPath: String) throws {
        let attachSQL = "ATTACH DATABASE '\(bundleDbPath)' AS bundle_db;"
        if let error = execute(sql: attachSQL, db: db) {
            throw MigrationError.executionFailed("ATTACH bundle failed: \(error)")
        }
        defer {
            _ = execute(sql: "DETACH DATABASE bundle_db;", db: db)
        }

        _ = execute(sql: "BEGIN TRANSACTION;", db: db)

        let mergeSQL = """
        INSERT OR IGNORE INTO main.english_table (
            word, word_normalized, phonex, frequency, meaning, pos, 
            example, example_cn, type, type_num, updated_at, is_deleted
        )
        SELECT 
            b.word, b.word_normalized, b.phonex, b.frequency, b.meaning, b.pos, 
            b.example, b.example_cn, b.type, b.type_num, b.updated_at, b.is_deleted
        FROM bundle_db.english_table AS b
        WHERE b.type IN ('chunk', 'sentence');
        """

        if let error = execute(sql: mergeSQL, db: db) {
            _ = execute(sql: "ROLLBACK;", db: db)
            throw MigrationError.executionFailed("V7 merge failed: \(error)")
        }

        _ = execute(sql: "COMMIT;", db: db)
        logger.info("V7 Migration: Chunks and sentences synchronized from master bundle.")
    }
    
  
    func migrateToV6(db: OpaquePointer?) throws {
        print("[DatabaseMigrator] Upgrading to V6 (Deduplication & Rigorous Sync)...")
    
        let dedupeChineseSQL = """
        DELETE FROM chinese_table 
        WHERE id NOT IN (
            SELECT MIN(id) FROM chinese_table GROUP BY word, pinyin
        );
        """
        _ = execute(sql: dedupeChineseSQL, db: db)
        
        let dedupeEnglishSQL = """
        DELETE FROM english_table 
        WHERE id NOT IN (
            SELECT MIN(id) FROM english_table GROUP BY word, type, type_num
        );
        """
        _ = execute(sql: dedupeEnglishSQL, db: db)

        let tablesToSync = ["chinese_table", "english_table", "learning_table", "cn_en_mapping"]
        for table in tablesToSync {
            _ = execute(sql: "ALTER TABLE \(table) ADD COLUMN updated_at INTEGER DEFAULT 0;", db: db)
            _ = execute(sql: "ALTER TABLE \(table) ADD COLUMN is_deleted INTEGER DEFAULT 0;", db: db)
            _ = execute(sql: "CREATE INDEX IF NOT EXISTS idx_\(table)_updated_at ON \(table) (updated_at);", db: db)
        }
        
        print("[DatabaseMigrator] Deploying unique constraints...")
        _ = execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_chinese_sync_anchor ON chinese_table (word, pinyin);", db: db)
        _ = execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_english_sync_anchor ON english_table (word, type, type_num);", db: db)
        _ = execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_mapping_sync_anchor ON cn_en_mapping (cn_id, en_id);", db: db)
        _ = execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS idx_learning_sync_anchor ON learning_table (cn_id, en_id);", db: db)

        let now = Int(Date().timeIntervalSince1970)
        let userAssetTables = ["learning_table"]
        for table in userAssetTables {
            _ = execute(sql: "UPDATE \(table) SET updated_at = \(now) WHERE updated_at = 0;", db: db)
        }
        
        print("[DatabaseMigrator] V6 Migration completed successfully.")
    }

    private func migrateToV5(db: OpaquePointer?) throws {
        
        if let error = execute(sql: "ALTER TABLE english_table ADD COLUMN word_normalized TEXT;", db: db) {
            if !error.contains("duplicate column name") {
                throw MigrationError.executionFailed("ALTER TABLE failed: \(error)")
            }
        }

        _ = execute(sql: "BEGIN TRANSACTION;", db: db)
        let updateSQL = "UPDATE english_table SET word_normalized = REPLACE(REPLACE(LOWER(word), \"'\", \"\"), \" \", \"\");"
        _ = execute(sql: updateSQL, db: db)
        _ = execute(sql: "COMMIT;", db: db)

        _ = execute(sql: "CREATE INDEX IF NOT EXISTS idx_english_normalized_freq ON english_table (word_normalized, frequency DESC);", db: db)
        _ = execute(sql: "CREATE INDEX IF NOT EXISTS idx_english_phonex_freq ON english_table (phonex, frequency DESC);", db: db)
        _ = execute(sql: "CREATE INDEX IF NOT EXISTS idx_english_word_freq ON english_table (word, frequency DESC);", db: db)
    }

    private func migrateToV4(db: OpaquePointer?, bundleDbPath: String) throws {
        if let error = execute(sql: "ALTER TABLE chinese_table ADD COLUMN word_trad TEXT;", db: db) {
            // Ignore error if column already exists
            if !error.contains("duplicate column name") {
                throw MigrationError.executionFailed("ALTER TABLE failed: \(error)")
            }
        }
        
        let attachSQL = "ATTACH DATABASE '\(bundleDbPath)' AS bundle_db;"
        if let error = execute(sql: attachSQL, db: db) {
            throw MigrationError.executionFailed("ATTACH bundle failed: \(error)")
        }
        
        defer {
            _ = execute(sql: "DETACH DATABASE bundle_db;", db: db)
        }
        
        _ = execute(sql: "BEGIN TRANSACTION;", db: db)
        
        print("[DatabaseMigrator] Resetting word_trad column for clean sync...")
        _ = execute(sql: "UPDATE chinese_table SET word_trad = NULL;", db: db)
        
        let updateSQL = """
        UPDATE chinese_table 
        SET word_trad = (
            SELECT b.word_trad 
            FROM bundle_db.chinese_table b 
            WHERE b.word = chinese_table.word 
            LIMIT 1
        )
        WHERE EXISTS (
            SELECT 1 FROM bundle_db.chinese_table b 
            WHERE b.word = chinese_table.word
        );
        """
        
        if let error = execute(sql: updateSQL, db: db) {
            _ = execute(sql: "ROLLBACK;", db: db)
            throw MigrationError.executionFailed("Data sync failed: \(error)")
        }
        
        let fillSQL = "UPDATE chinese_table SET word_trad = word WHERE word_trad IS NULL;"
        _ = execute(sql: fillSQL, db: db)
        
        _ = execute(sql: "CREATE INDEX IF NOT EXISTS idx_chinese_word_trad ON chinese_table (word_trad);", db: db)
        
        _ = execute(sql: "COMMIT;", db: db)
    }

    private func getDatabaseVersion(db: OpaquePointer?) -> Int32 {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let version = sqlite3_column_int(statement, 0)
                sqlite3_finalize(statement)
                return version
            }
        }
        sqlite3_finalize(statement)
        return 0
    }

    private func setDatabaseVersion(_ version: Int32, db: OpaquePointer?) {
        _ = execute(sql: "PRAGMA user_version = \(version);", db: db)
    }

    private func mergePatchWithConnection(db: OpaquePointer?, patchDbPath: String) throws {
        let attachSQL = "ATTACH DATABASE '\(patchDbPath)' AS patch;"
        if let error = execute(sql: attachSQL, db: db) {
            print("[DatabaseMigrator] ATTACH failed: \(error)")
            throw MigrationError.attachPatchFailed
        }
        
        _ = execute(sql: "BEGIN TRANSACTION;", db: db)
        
        do {
            let indexSQL = "CREATE INDEX IF NOT EXISTS idx_stroke_covering ON chinese_table (stroke, frequency DESC, word, pinyin, id);"
            _ = execute(sql: indexSQL, db: db)

            let insertEnglishSQL = """
            INSERT OR IGNORE INTO main.english_table (word, pos, meaning, example, example_cn, frequency, type, type_num)
            SELECT word, pos, meaning, example, example_cn, frequency, type, type_num
            FROM patch.english_table;
            """
            if let error = execute(sql: insertEnglishSQL, db: db) {
                throw MigrationError.executionFailed("English merge failed: \(error)")
            }
            
            let insertMappingSQL = """
            INSERT OR IGNORE INTO main.cn_en_mapping (cn_id, en_id)
            SELECT pm.cn_id, em.id FROM patch.cn_en_mapping pm
            JOIN patch.english_table pe ON pm.en_id = pe.id
            JOIN main.english_table em ON pe.word = em.word AND pe.type = em.type AND pe.type_num = em.type_num;
            """
            _ = execute(sql: insertMappingSQL, db: db)
            
            _ = execute(sql: "COMMIT;", db: db)
            _ = execute(sql: "DETACH DATABASE patch;", db: db)
            
        } catch {
            _ = execute(sql: "ROLLBACK;", db: db)
            _ = execute(sql: "DETACH DATABASE patch;", db: db)
            throw error
        }
    }

    private func migrateToV3(db: OpaquePointer?) throws {
        print("[DatabaseMigrator] Adding phonex column to main.english_table...")
        
        if let error = execute(sql: "ALTER TABLE main.english_table ADD COLUMN phonex TEXT;", db: db) {
            if !error.contains("duplicate column name") {
                throw MigrationError.executionFailed("ALTER TABLE failed: \(error)")
            }
        }
        
        _ = execute(sql: "PRAGMA schema_version;", db: db)

        var statement: OpaquePointer?
        let querySQL = "SELECT id, word FROM main.english_table WHERE phonex IS NULL;"
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            throw MigrationError.executionFailed("Prepare failed: \(error)")
        }

        var updates: [(Int64, String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            if let cString = sqlite3_column_text(statement, 1) {
                let word = String(cString: cString)
                let code = Phonex.encode(word)
                updates.append((id, code))
            }
        }
        sqlite3_finalize(statement)

        print("[DatabaseMigrator] Batch updating \(updates.count) phonex codes...")
        _ = execute(sql: "BEGIN TRANSACTION;", db: db)
        let updateSQL = "UPDATE main.english_table SET phonex = ? WHERE id = ?;"
        var updateStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK {
            for (id, code) in updates {
                sqlite3_bind_text(updateStmt, 1, (code as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(updateStmt, 2, id)
                sqlite3_step(updateStmt)
                sqlite3_reset(updateStmt)
            }
        }
        sqlite3_finalize(updateStmt)
        _ = execute(sql: "COMMIT;", db: db)

        _ = execute(sql: "CREATE INDEX IF NOT EXISTS idx_english_phonex ON english_table(phonex);", db: db)
    }

    func mergePatchDatabase(mainDbPath: String, patchDbPath: String) throws {
        runMigrations(dbPath: mainDbPath, patchDbPath: patchDbPath)
    }
    
    private func execute(sql: String, db: OpaquePointer?) -> String? {
        var errorMessage: UnsafeMutablePointer<Int8>? = nil
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let errorStr = errorMessage.map { String(cString: $0) } ?? "Unknown SQL error"
            if let ptr = errorMessage { sqlite3_free(ptr) }
            return errorStr
        }
        return nil
    }
}
