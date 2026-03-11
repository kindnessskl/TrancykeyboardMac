import Foundation
import CloudKit
import CryptoKit
import OSLog

class iCloudSyncManager {
    static let shared = iCloudSyncManager()
    private let logger = Logger(subsystem: "com.trancy.keyboard", category: "Sync")
    private let container = CKContainer(identifier: AppConstants.Database.icloudContainerIdentifier)
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private let database: DatabaseManager
    private let lastSyncKey = "com.trancy.sync.lastSyncTimestamp"
    private let syncQueue = DispatchQueue(label: "com.trancy.sync.engine", qos: .utility)
    private var isSyncing = false
    private let syncThreshold: Int = 300
    
    private var deviceID: String {
        if let id = SharedUserDefaults.shared.string(forKey: "com.trancy.sync.deviceID") {
            return id
        }
        let newID = UUID().uuidString
        SharedUserDefaults.shared.set(newID, forKey: "com.trancy.sync.deviceID")
        SharedUserDefaults.shared.synchronize()
        return newID
    }
    
    init(database: DatabaseManager = PinyinRepository.shared.database) {
        self.database = database
    }
    
    func performSync(force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard SharedUserDefaults.shared.bool(forKey: "isCloudSyncEnabled") else {
            completion?(false)
            return
        }
        guard !isSyncing else {
            logger.info(">>> Sync already in progress, skipping.")
            completion?(false)
            return
        }
        let lastSync = SharedUserDefaults.shared.integer(forKey: self.lastSyncKey)
        let now = Int(Date().timeIntervalSince1970)
        if !force && (now - lastSync) < syncThreshold {
            completion?(false)
            return
        }
        isSyncing = true
        syncQueue.async {
            self.logger.info(">>> SYNC START. Anchor: \(lastSync)")
            self.pushChanges(since: lastSync) { pushSuccess in
                self.logger.info(">>> PUSH FINISHED (Success: \(pushSuccess)). Starting pull phase...")
                self.pullChanges(since: lastSync) { pullSuccess in
                    self.isSyncing = false
                    if pullSuccess {
                        let nextSyncAnchor = Int(Date().timeIntervalSince1970)
                        SharedUserDefaults.shared.set(nextSyncAnchor, forKey: self.lastSyncKey)
                        SharedUserDefaults.shared.synchronize()
                        self.logger.info(">>> SYNC CYCLE COMPLETED. New anchor: \(nextSyncAnchor)")
                    } else {
                        self.logger.error(">>> PULL PHASE FAILED.")
                    }
                    DispatchQueue.main.async {
                        completion?(pullSuccess)
                    }
                }
            }
        }
    }
    private func pushChanges(since timestamp: Int, completion: @escaping (Bool) -> Void) {
        let tables = ["chinese_table", "english_table", "learning_table", "cn_en_mapping"]
        var uniqueRecords = [CKRecord.ID: CKRecord]()
        for table in tables {
            let sql = "SELECT * FROM \(table) WHERE updated_at > ?"
            let rows = database.executeQuery(sql, parameters: [timestamp])
            for row in rows {
                if let record = packageRecord(table: table, row: row) {
                    uniqueRecords[record.recordID] = record
                }
            }
        }
        let allRecords = Array(uniqueRecords.values)
        guard !allRecords.isEmpty else {
            self.logger.info("No local data needs pushing.")
            completion(true)
            return
        }
        self.logger.info("Pushing \(allRecords.count) records in batches...")
        let recordChunks = allRecords.chunked2(into: 100)
        self.uploadBatchesSerially(recordChunks, currentIndex: 0, completion: completion)
    }
    private func uploadBatchesSerially(_ chunks: [[CKRecord]], currentIndex: Int, completion: @escaping (Bool) -> Void) {
        guard currentIndex < chunks.count else {
            completion(true)
            return
        }
        let chunk = chunks[currentIndex]
        let op = CKModifyRecordsOperation(recordsToSave: chunk, recordIDsToDelete: nil)
        op.savePolicy = .changedKeys
        op.qualityOfService = .utility
        op.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                self.logger.info(">>> Batch \(currentIndex + 1)/\(chunks.count) successfully pushed.")
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                    self.uploadBatchesSerially(chunks, currentIndex: currentIndex + 1, completion: completion)
                }
            case .failure(let error):
                self.logger.error(">>> Batch \(currentIndex + 1) FAILED: \(error.localizedDescription)")
                completion(false)
            }
        }
        privateDB.add(op)
    }
    private func pullChanges(since timestamp: Int, completion: @escaping (Bool) -> Void) {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp)) as NSDate
        let predicate = NSPredicate(format: "modificationDate > %@", date)
        let baseTables = ["chinese_table", "english_table"]
        let relationTables = ["learning_table", "cn_en_mapping"]
        self.pullTablesSerially(groups: [baseTables, relationTables], predicate: predicate, completion: completion)
    }
    private func pullTablesSerially(groups: [[String]], predicate: NSPredicate, completion: @escaping (Bool) -> Void) {
        guard !groups.isEmpty else {
            completion(true)
            return
        }
        var remainingGroups = groups
        let currentGroup = remainingGroups.removeFirst()
        let group = DispatchGroup()
        var hasError = false
        for table in currentGroup {
            group.enter()
            let query = CKQuery(recordType: table, predicate: predicate)
            let op = CKQueryOperation(query: query)
            op.qualityOfService = .utility
            op.recordMatchedBlock = { _, result in
                if let record = try? result.get() {
                    self.mergeSingleRecord(record: record, table: table)
                }
            }
            op.queryResultBlock = { result in
                if case .failure(let error) = result {
                    if (error as NSError).code != 11 {
                        self.logger.error("Fetch failed for \(table): \(error.localizedDescription)")
                        hasError = true
                    }
                }
                group.leave()
            }
            privateDB.add(op)
        }
        group.notify(queue: syncQueue) {
            if hasError {
                completion(false)
            } else {
                self.pullTablesSerially(groups: remainingGroups, predicate: predicate, completion: completion)
            }
        }
    }
    private func mergeSingleRecord(record: CKRecord, table: String) {
        if let recordClientID = record["client_id"] as? String, recordClientID == deviceID {
            return
        }
        let remoteUpdatedAt = record["updated_at"] as? Int ?? 0
        let localUpdatedAt = getLocalUpdatedAt(record: record, table: table)
        if remoteUpdatedAt <= localUpdatedAt {
            return
        }
        _ = database.beginTransaction()
        applyRecordToLocal(record: record, table: table)
        _ = database.commitTransaction()
    }
    private func getLocalUpdatedAt(record: CKRecord, table: String) -> Int {
        if table == "chinese_table" {
            let word = record["word"] as? String ?? ""
            let pinyin = record["pinyin"] as? String ?? ""
            let sql = "SELECT updated_at FROM chinese_table WHERE word = ? AND pinyin = ?"
            return database.executeQuery(sql, parameters: [word, pinyin]).first?["updated_at"] as? Int ?? 0
        } else if table == "english_table" {
            let word = record["word"] as? String ?? ""
            let type = record["type"] as? String ?? ""
            if type == "api" || type == "user_added" {
                let sql = "SELECT updated_at FROM english_table WHERE word = ? AND type = ?"
                return database.executeQuery(sql, parameters: [word, type]).first?["updated_at"] as? Int ?? 0
            } else {
                let typeNum = record["type_num"] as? Int ?? 0
                let sql = "SELECT updated_at FROM english_table WHERE word = ? AND type = ? AND type_num = ?"
                return database.executeQuery(sql, parameters: [word, type, typeNum]).first?["updated_at"] as? Int ?? 0
            }
        } else {
            let ids = resolveLocalIDs(from: record)
            guard let cid = ids.cnId, let eid = ids.enId else { return 0 }
            return database.executeQuery("SELECT updated_at FROM \(table) WHERE cn_id = ? AND en_id = ?", parameters: [cid, eid]).first?["updated_at"] as? Int ?? 0
        }
    }
    private func applyRecordToLocal(record: CKRecord, table: String) {
        let isDeleted = (record["is_deleted"] as? Int ?? 0) == 1
        switch table {
        case "chinese_table":
            let word = record["word"] as? String ?? ""
            let pinyin = record["pinyin"] as? String ?? ""
            if isDeleted {
                self.logger.info("🗑 [Sync] Deleting Chinese word: \(word) (\(pinyin))")
                _ = database.executeUpdate("DELETE FROM chinese_table WHERE word = ? AND pinyin = ?", parameters: [word as Any, pinyin as Any])
            } else {
                self.logger.info("💾 [Sync] Upserting Chinese word: \(word) (\(pinyin))")
                let sql = """
                INSERT INTO chinese_table (word, word_trad, pinyin, pinyin_abbr, frequency, stroke, updated_at, is_deleted) 
                VALUES (?, ?, ?, ?, ?, ?, ?, 0)
                ON CONFLICT(word, pinyin) DO UPDATE SET 
                    word_trad = excluded.word_trad,
                    pinyin_abbr = excluded.pinyin_abbr,
                    frequency = excluded.frequency,
                    stroke = excluded.stroke,
                    updated_at = excluded.updated_at,
                    is_deleted = 0;
                """
                _ = database.executeUpdate(sql, parameters: [word as Any, record["word_trad"] as Any, pinyin as Any, record["pinyin_abbr"] as Any, record["frequency"] as Any, record["stroke"] as Any, record["updated_at"] as Any])
            }
        case "english_table":
            let word = record["word"] as? String ?? ""
            let type = record["type"] as? String ?? ""
            let typeNum = record["type_num"] as? Int ?? 0
            if isDeleted {
                self.logger.info("🗑 [Sync] Deleting English word: \(word) (Type: \(type))")
                if type == "api" || type == "user_added" {
                    _ = database.executeUpdate("DELETE FROM english_table WHERE word = ? AND type = ?", parameters: [word, type])
                } else {
                    _ = database.executeUpdate("DELETE FROM english_table WHERE word = ? AND type = ? AND type_num = ?", parameters: [word, type, typeNum])
                }
            } else {
                var existingId: Int?
                if type == "api" || type == "user_added" {
                    existingId = database.executeQuery("SELECT id FROM english_table WHERE word = ? AND type = ? LIMIT 1", parameters: [word, type]).first?["id"] as? Int
                } else {
                    existingId = database.executeQuery("SELECT id FROM english_table WHERE word = ? AND type = ? AND type_num = ? LIMIT 1", parameters: [word, type, typeNum]).first?["id"] as? Int
                }
                if let id = existingId {
                    self.logger.info("♻️ [Sync] Updating existing English word (ID: \(id)): \(word)")
                    let sql = """
                    UPDATE english_table SET
                        pos = ?, meaning = ?, ipa = ?, example = ?, example_cn = ?,
                        frequency = ?, phonex = ?, word_normalized = ?, updated_at = ?, is_deleted = 0
                    WHERE id = ?;
                    """
                    _ = database.executeUpdate(sql, parameters: [record["pos"] as Any, record["meaning"] as Any, record["ipa"] as Any, record["example"] as Any, record["example_cn"] as Any, record["frequency"] as Any, record["phonex"] as Any, record["word_normalized"] as Any, record["updated_at"] as Any, id])
                } else {
                    self.logger.info("🆕 [Sync] Inserting new English word: \(word) (Type: \(type))")
                    var newTypeNum = typeNum
                    if type == "api" || type == "user_added" {
                        let maxNum = database.executeQuery("SELECT MAX(type_num) as max_num FROM english_table WHERE type = ?", parameters: [type]).first?["max_num"] as? Int ?? 0
                        newTypeNum = maxNum + 1
                    }
                    let sql = """
                    INSERT INTO english_table (word, pos, meaning, ipa, example, example_cn, frequency, type, type_num, phonex, word_normalized, updated_at, is_deleted) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0);
                    """
                    _ = database.executeUpdate(sql, parameters: [word, record["pos"] as Any, record["meaning"] as Any, record["ipa"] as Any, record["example"] as Any, record["example_cn"] as Any, record["frequency"] as Any, type, newTypeNum, record["phonex"] as Any, record["word_normalized"] as Any, record["updated_at"] as Any])
                }
            }
        case "learning_table", "cn_en_mapping":
            var (cid, eid) = resolveLocalIDs(from: record)
            if cid == nil, let cnWord = record["sync_cn_word"] as? String, let cnPinyin = record["sync_cn_pinyin"] as? String {
                self.logger.info("🛠 [Sync] Missing local Chinese word '\(cnWord)', creating skeleton...")
                let now = Int(Date().timeIntervalSince1970)
                let sql = "INSERT INTO chinese_table (word, word_trad, pinyin, pinyin_abbr, frequency, stroke, updated_at, is_deleted) VALUES (?, ?, ?, '', 1, '', ?, 0)"
                _ = database.executeInsert(sql, parameters: [cnWord, cnWord, cnPinyin, now])
                cid = database.executeQuery("SELECT id FROM chinese_table WHERE word = ? AND pinyin = ? LIMIT 1", parameters: [cnWord, cnPinyin]).first?["id"] as? Int
            }
            if eid == nil, let enWord = record["sync_en_word"] as? String, let enType = record["sync_en_type"] as? String {
                self.logger.info("🛠 [Sync] Missing local English word '\(enWord)', creating skeleton...")
                let now = Int(Date().timeIntervalSince1970)
                let enTypeNum = record["sync_en_type_num"] as? Int ?? 1
                let phonex = Phonex.encode(enWord)
                let normalized = enWord.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: " ", with: "")
                let sql = """
                INSERT INTO english_table (word, pos, meaning, ipa, example, example_cn, frequency, type, type_num, phonex, word_normalized, updated_at, is_deleted) 
                VALUES (?, '', '', '', '', '', 1, ?, ?, ?, ?, ?, 0)
                """
                _ = database.executeInsert(sql, parameters: [enWord, enType, enTypeNum, phonex, normalized, now])
                eid = database.executeQuery("SELECT id FROM english_table WHERE word = ? AND type = ? AND type_num = ? LIMIT 1", parameters: [enWord, enType, enTypeNum]).first?["id"] as? Int
            }
            guard let validCid = cid, let validEid = eid else {
                self.logger.error("❌ [Sync] Critical: Failed to resolve or create local IDs for \(table).")
                return
            }
            if isDeleted {
                self.logger.info("🗑 [Sync] Deleting relation in \(table): CN_ID:\(validCid), EN_ID:\(validEid)")
                _ = database.executeUpdate("DELETE FROM \(table) WHERE cn_id = ? AND en_id = ?", parameters: [validCid, validEid])
            } else if table == "cn_en_mapping" {
                self.logger.info("🔗 [Sync] Upserting mapping: CN_ID:\(validCid), EN_ID:\(validEid)")
                let sql = """
                INSERT INTO cn_en_mapping (cn_id, en_id, updated_at, is_deleted) 
                VALUES (?, ?, ?, 0)
                ON CONFLICT(cn_id, en_id) DO UPDATE SET 
                    updated_at = excluded.updated_at,
                    is_deleted = 0;
                """
                _ = database.executeUpdate(sql, parameters: [validCid, validEid, record["updated_at"] as Any])
            } else {
                self.logger.info("📝 [Sync] Upserting learning record: CN_ID:\(validCid), EN_ID:\(validEid)")
                let sql = """
                INSERT INTO learning_table (cn_id, en_id, rank, favorite, mark, remind_data, photo_identifier, last_used_date, count, category_type, group_num, updated_at, is_deleted) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                ON CONFLICT(cn_id, en_id) DO UPDATE SET 
                    rank = excluded.rank,
                    favorite = excluded.favorite,
                    mark = excluded.mark,
                    remind_data = excluded.remind_data,
                    photo_identifier = excluded.photo_identifier,
                    last_used_date = excluded.last_used_date,
                    count = excluded.count,
                    category_type = excluded.category_type,
                    group_num = excluded.group_num,
                    updated_at = excluded.updated_at,
                    is_deleted = 0;
                """
                _ = database.executeUpdate(sql, parameters: [validCid, validEid, record["rank"] as Any, record["favorite"] as Any, record["mark"] as Any, record["remind_data"] as Any, record["photo_identifier"] as Any, record["last_used_date"] as Any, record["count"] as Any, record["category_type"] as Any, record["group_num"] as Any, record["updated_at"] as Any])
            }
        default: break
        }
    }
    private func resolveLocalIDs(from record: CKRecord) -> (cnId: Int?, enId: Int?) {
        guard let cnWord = record["sync_cn_word"] as? String,
              let cnPinyin = record["sync_cn_pinyin"] as? String,
              let enWord = record["sync_en_word"] as? String,
              let enType = record["sync_en_type"] as? String,
              let enTypeNum = record["sync_en_type_num"] as? Int else { return (nil, nil) }
        let cnId = database.executeQuery("SELECT id FROM chinese_table WHERE word = ? AND pinyin = ? LIMIT 1", parameters: [cnWord, cnPinyin]).first?["id"] as? Int
        var enId: Int?
        if enType == "api" || enType == "user_added" {
            enId = database.executeQuery("SELECT id FROM english_table WHERE word = ? AND type = ? LIMIT 1", parameters: [enWord, enType]).first?["id"] as? Int
        } else {
            enId = database.executeQuery("SELECT id FROM english_table WHERE word = ? AND type = ? AND type_num = ? LIMIT 1", parameters: [enWord, enType, enTypeNum]).first?["id"] as? Int
        }
        return (cnId, enId)
    }
    private func packageRecord(table: String, row: [String: Any]) -> CKRecord? {
        var businessKey = ""
        var extraFields = [String: CKRecordValue]()
        switch table {
        case "chinese_table":
            guard let word = row["word"] as? String, let pinyin = row["pinyin"] as? String else { return nil }
            businessKey = "cn_\(word)_\(pinyin)"
        case "english_table":
            guard let word = row["word"] as? String, let type = row["type"] as? String, let typeNum = row["type_num"] as? Int else { return nil }
            if type == "api" || type == "user_added" {
                businessKey = "en_\(word)_\(type)"
            } else {
                businessKey = "en_\(word)_\(type)_\(typeNum)"
            }
        case "learning_table", "cn_en_mapping":
            let cnId = row["cn_id"] as? Int ?? 0
            let enId = row["en_id"] as? Int ?? 0
            let cnRow = database.executeQuery("SELECT word, pinyin FROM chinese_table WHERE id = ?", parameters: [cnId]).first
            let enRow = database.executeQuery("SELECT word, type, type_num FROM english_table WHERE id = ?", parameters: [enId]).first
            guard let cr = cnRow, let er = enRow else { return nil }
            let cnWord = cr["word"] as? String ?? "", cnPinyin = cr["pinyin"] as? String ?? "",
                enWord = er["word"] as? String ?? "", enType = er["type"] as? String ?? "", enTypeNum = er["type_num"] as? Int ?? 0
            if enType == "api" || enType == "user_added" {
                businessKey = "\(table)_\(cnWord)_\(cnPinyin)_\(enWord)_\(enType)"
            } else {
                businessKey = "\(table)_\(cnWord)_\(cnPinyin)_\(enWord)_\(enType)_\(enTypeNum)"
            }
            extraFields["sync_cn_word"] = cnWord as CKRecordValue
            extraFields["sync_cn_pinyin"] = cnPinyin as CKRecordValue
            extraFields["sync_en_word"] = enWord as CKRecordValue
            extraFields["sync_en_type"] = enType as CKRecordValue
            extraFields["sync_en_type_num"] = enTypeNum as CKRecordValue
        default: return nil
        }
        let recordID = CKRecord.ID(recordName: generateSecureHash(from: businessKey))
        let record = CKRecord(recordType: table, recordID: recordID)
        record["client_id"] = deviceID as CKRecordValue
        for (key, value) in row {
            if ["id", "cn_id", "en_id", "client_id"].contains(key) || key.contains("path") { continue }
            if let val = value as? CKRecordValue { record[key] = val }
            else if let intVal = value as? Int { record[key] = intVal as CKRecordValue }
        }
        extraFields.forEach { record[$0.key] = $0.value }
        return record
    }
    private func generateSecureHash(from input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
extension Array {
    func chunked2(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0 ..< Swift.min($0 + size, count)]) }
    }
}
