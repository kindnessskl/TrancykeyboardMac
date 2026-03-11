import Foundation
import SQLCipher
import os.log

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

class DatabaseManager {
    private var db: OpaquePointer?
    let dbPath: String
    private let password: String?
    private let queue = DispatchQueue(label: "com.trancy.keyboard.database", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.trancy.keyboard.datebase", category: "Database")
    private(set) var isConnected: Bool = false
    private(set) var lastError: String?

    init(dbPath: String, password: String? = nil) {
        self.dbPath = dbPath
        self.password = password
    }

    deinit {
        close()
    }

    func open() -> Bool {
        guard db == nil else {
            isConnected = true
            return true
        }

        let parentPath = (dbPath as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: parentPath) {
            do {
                try FileManager.default.createDirectory(atPath: parentPath, withIntermediateDirectories: true)
            } catch {
                logger.error("❌ 创建目录失败: \(error.localizedDescription)")
                return false
            }
        }

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            lastError = getLastError() ?? "Unknown error"
            isConnected = false
            return false
        }

        if let password = password, !password.isEmpty {
            
            let safePassword = password.replacingOccurrences(of: "'", with: "''")
            let pragmaSql = "PRAGMA key = '\(safePassword)';"
            
            if sqlite3_exec(db, pragmaSql, nil, nil, nil) != SQLITE_OK {
                close()
                return false
            }
            
            if sqlite3_exec(db, "SELECT count(*) FROM sqlite_master;", nil, nil, nil) != SQLITE_OK {
                _ = getLastError() ?? "Unknown"
                lastError = "SQLCipher: Invalid password"
                close()
                return false
            }
            logger.log(" 解锁成功！数据库已准备就绪。")
        } else {
            logger.warning("未检测到密码，将以普通模式访问。")
        }

        isConnected = true
        lastError = nil
        return true
    }

    func close() {
        guard db != nil else { return }
        sqlite3_close(db)
        db = nil
        isConnected = false
    }

    func isOpen() -> Bool {
        return db != nil && isConnected
    }

    func executeQuery(_ sql: String, parameters: [Any] = []) -> [[String: Any]] {
        var results: [[String: Any]] = []

        queue.sync {
            guard isOpen() else { return }

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
                return
            }

            bindParameters(statement: statement, parameters: parameters)

            while sqlite3_step(statement) == SQLITE_ROW {
                var row: [String: Any] = [:]
                let columnCount = sqlite3_column_count(statement)

                for i in 0..<columnCount {
                    let columnName = String(cString: sqlite3_column_name(statement, i))
                    let columnValue = getColumnValue(statement: statement, index: i)
                    row[columnName] = columnValue
                }

                results.append(row)
            }

            sqlite3_finalize(statement)
        }

        return results
    }

    func executeUpdate(_ sql: String, parameters: [Any] = []) -> Bool {
        var success = false

        queue.sync {
            guard isOpen() else { return }

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
                return
            }

            bindParameters(statement: statement, parameters: parameters)

            success = sqlite3_step(statement) == SQLITE_DONE

            sqlite3_finalize(statement)
        }

        return success
    }

    func executeInsert(_ sql: String, parameters: [Any] = []) -> Int64? {
        var insertId: Int64?

        queue.sync {
            guard isOpen() else { return }

            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
                return
            }

            bindParameters(statement: statement, parameters: parameters)

            if sqlite3_step(statement) == SQLITE_DONE {
                insertId = sqlite3_last_insert_rowid(db)
            }

            sqlite3_finalize(statement)
        }

        return insertId
    }

    func lastInsertRowId() -> Int64 {
        var rowId: Int64 = 0
        queue.sync {
            guard isOpen() else { return }
            rowId = sqlite3_last_insert_rowid(db)
        }
        return rowId
    }

    func beginTransaction() -> Bool {
        return executeUpdate("BEGIN TRANSACTION")
    }

    func commitTransaction() -> Bool {
        return executeUpdate("COMMIT")
    }

    func rollbackTransaction() -> Bool {
        return executeUpdate("ROLLBACK")
    }

    func executeBatch(_ operations: [(sql: String, parameters: [Any])]) -> Bool {
        var success = true
        
        queue.sync {
            guard isOpen() else {
                success = false
                return
            }
            
            if !beginTransaction() {
                success = false
                return
            }
            
            for operation in operations {
                if !executeUpdate(operation.sql, parameters: operation.parameters) {
                    success = false
                    break
                }
            }
            
            if success {
                success = commitTransaction()
            } else {
                _ = rollbackTransaction()
            }
        }
        
        return success
    }

    private func bindParameters(statement: OpaquePointer?, parameters: [Any]) {
        guard let statement = statement else { return }

        for (index, param) in parameters.enumerated() {
            let bindIndex = Int32(index + 1)

            if let stringValue = param as? String {
                sqlite3_bind_text(statement, bindIndex, stringValue, -1, SQLITE_TRANSIENT)
            } else if let intValue = param as? Int {
                sqlite3_bind_int64(statement, bindIndex, Int64(intValue))
            } else if let doubleValue = param as? Double {
                sqlite3_bind_double(statement, bindIndex, doubleValue)
            } else if param is NSNull {
                sqlite3_bind_null(statement, bindIndex)
            }
        }
    }

    private func getColumnValue(statement: OpaquePointer?, index: Int32) -> Any {
        guard let statement = statement else { return NSNull() }

        let columnType = sqlite3_column_type(statement, index)

        switch columnType {
        case SQLITE_INTEGER:
            return Int(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return sqlite3_column_double(statement, index)
        case SQLITE_TEXT:
            if let cString = sqlite3_column_text(statement, index) {
                return String(cString: cString)
            }
            return ""
        case SQLITE_NULL:
            return NSNull()
        default:
            return NSNull()
        }
    }

    func getLastError() -> String? {
        guard let db = db else { return nil }
        if let errorPointer = sqlite3_errmsg(db) {
            return String(cString: errorPointer)
        }
        return nil
    }
}
