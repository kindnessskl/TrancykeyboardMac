import Foundation

extension PinyinRepository {
    func updateChineseWordFrequency(chineseId: Int, pinyin: String) -> Bool {
        let now = Int(Date().timeIntervalSince1970)
        let sql = "UPDATE chinese_table SET frequency = frequency + 10000, updated_at = ? WHERE id = ?"
        return database.executeUpdate(sql, parameters: [now, chineseId])
    }
    
    func updateEnglishWordFrequency(englishId: Int) -> Bool {
        let now = Int(Date().timeIntervalSince1970)
        let sql = "UPDATE english_table SET frequency = frequency + 10000, updated_at = ? WHERE id = ?"
        return database.executeUpdate(sql, parameters: [now, englishId])
    }

    func insertLearningRecord(chineseId: Int?, englishId: Int?) -> Bool {
        return insertOrUpdateLearningRecord(cnId: chineseId, enId: englishId)
    }
    
    func insertLearningRecordWithWords(chineseWord: String, englishWord: String) -> Bool {
        let cnId = insertChineseWordIfNotExists(chineseWord)
        let enId = insertEnglishWordIfNotExists(englishWord)
        guard cnId > 0 && enId > 0 else { return false }
        _ = insertMappingIfNotExists(cnId: cnId, enId: enId)
        return insertOrUpdateLearningRecord(cnId: cnId, enId: enId)
    }

    func updateFavoriteStatus(cnId: Int, englishId: Int, favorite: Bool) -> Bool {
        return insertOrUpdateLearningField(cnId: cnId, englishId: englishId, field: "favorite", value: favorite ? 1 : 0)
    }
    
    func updateRank(cnId: Int, englishId: Int, rank: Int) -> Bool {
        return insertOrUpdateLearningField(cnId: cnId, englishId: englishId, field: "rank", value: rank)
    }
    
    func updateRemindData(cnId: Int, englishId: Int, remindData: String) -> Bool {
        return insertOrUpdateLearningField(cnId: cnId, englishId: englishId, field: "remind_data", value: remindData)
    }
    
    func updateMark(cnId: Int, englishId: Int, mark: String) -> Bool {
        return insertOrUpdateLearningField(cnId: cnId, englishId: englishId, field: "mark", value: mark)
    }

    func updatePhotoIdentifier(cnId: Int, englishId: Int, photoIdentifier: String) -> Bool {
        return insertOrUpdateLearningField(cnId: cnId, englishId: englishId, field: "photo_identifier", value: photoIdentifier)
    }
    
    func removePhotoIdentifier(cnId: Int, englishId: Int) -> Bool {
        return insertOrUpdateLearningField(cnId: cnId, englishId: englishId, field: "photo_identifier", value: "")
    }

    func addChineseWord(word: String, pinyin: String, pinyinAbbr: String, stroke: String, frequency: Int) -> Int {
        if let id = getChineseWordId(word) { return id }
        let now = Int(Date().timeIntervalSince1970)
        let sql = "INSERT INTO chinese_table (word, word_trad, pinyin, pinyin_abbr, frequency, stroke, updated_at, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?, 0)"
        return Int(database.executeInsert(sql, parameters: [word, word, pinyin, pinyinAbbr, frequency, stroke, now]) ?? 0)
    }

    func insertChineseWord(_ word: String, pinyin: String = "") -> Int {
        return insertChineseWordIfNotExists(word, pinyin: pinyin)
    }

    func addEnglishWord(word: String, pos: String, meaning: String, ipa: String, example: String, exampleCn: String, frequency: Int, cnId: Int?) -> Bool {
        var englishId = getEnglishWordId(word) ?? 0
        let now = Int(Date().timeIntervalSince1970)
        if englishId == 0 {
            let nextTypeNum = getNextTypeNum(for: "user_added")
            let phonex = Phonex.encode(word)
            let normalized = word.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: " ", with: "")
            let sql = "INSERT INTO english_table (word, pos, meaning, ipa, example, example_cn, frequency, type, type_num, phonex, word_normalized, updated_at, is_deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)"
            englishId = Int(database.executeInsert(sql, parameters: [word, pos, meaning, ipa, example, exampleCn, frequency, "user_added", nextTypeNum, phonex, normalized, now]) ?? 0)
        }
        guard englishId > 0 else { return false }
        if let validCnId = cnId, validCnId > 0 { _ = insertMappingIfNotExists(cnId: validCnId, enId: englishId) }
        return insertOrUpdateLearningRecord(cnId: cnId, enId: englishId)
    }

    func updateChineseAndEnglishTables(cnId: Int, chineseWord: String, pinyin: String, pinyinAbbr: String, stroke: String, chineseFrequency: Int, enId: Int, englishWord: String, pos: String, meaning: String, ipa: String, example: String, exampleCn: String, englishFrequency: Int) -> Bool {
        let now = Int(Date().timeIntervalSince1970)
        var chineseSuccess = true
        if cnId > 0 {
            let sql = "UPDATE chinese_table SET word = ?, word_trad = ?, pinyin = ?, pinyin_abbr = ?, stroke = ?, frequency = ?, updated_at = ? WHERE id = ?"
            chineseSuccess = database.executeUpdate(sql, parameters: [chineseWord, chineseWord, pinyin, pinyinAbbr, stroke, chineseFrequency, now, cnId])
        }
        let englishSuccess = database.executeUpdate("UPDATE english_table SET word = ?, pos = ?, meaning = ?, ipa = ?, example = ?, example_cn = ?, frequency = ?, updated_at = ? WHERE id = ?", parameters: [englishWord, pos, meaning, ipa, example, exampleCn, englishFrequency, now, enId])
        return chineseSuccess && englishSuccess
    }

    // MARK: - 同步删除支持 (软删除/物理删除动态切换)
    
    func deleteLearningRecord(enId: Int) -> Bool {
        let isSyncEnabled = SharedUserDefaults.shared.bool(forKey: "isCloudSyncEnabled")
        if isSyncEnabled {
            let now = Int(Date().timeIntervalSince1970)
            return database.executeUpdate("UPDATE learning_table SET is_deleted = 1, updated_at = ? WHERE en_id = ?", parameters: [now, enId])
        } else {
            return database.executeUpdate("DELETE FROM learning_table WHERE en_id = ?", parameters: [enId])
        }
    }
    
    func deleteWord(enId: Int) -> Bool {
        let isSyncEnabled = SharedUserDefaults.shared.bool(forKey: "isCloudSyncEnabled")
        if isSyncEnabled {
            let now = Int(Date().timeIntervalSince1970)
            _ = database.executeUpdate("UPDATE learning_table SET is_deleted = 1, updated_at = ? WHERE en_id = ?", parameters: [now, enId])
            _ = database.executeUpdate("UPDATE cn_en_mapping SET is_deleted = 1, updated_at = ? WHERE en_id = ?", parameters: [now, enId])
            return database.executeUpdate("UPDATE english_table SET is_deleted = 1, updated_at = ? WHERE id = ?", parameters: [now, enId])
        } else {
            _ = database.executeUpdate("DELETE FROM learning_table WHERE en_id = ?", parameters: [enId])
            _ = database.executeUpdate("DELETE FROM cn_en_mapping WHERE en_id = ?", parameters: [enId])
            return database.executeUpdate("DELETE FROM english_table WHERE id = ?", parameters: [enId])
        }
    }
    
    func deleteChineseWord(cnId: Int) -> Bool {
        guard cnId > 0 else { return false }
        let isSyncEnabled = SharedUserDefaults.shared.bool(forKey: "isCloudSyncEnabled")
        if isSyncEnabled {
            let now = Int(Date().timeIntervalSince1970)
            _ = database.executeUpdate("UPDATE learning_table SET is_deleted = 1, updated_at = ? WHERE cn_id = ?", parameters: [now, cnId])
            _ = database.executeUpdate("UPDATE cn_en_mapping SET is_deleted = 1, updated_at = ? WHERE cn_id = ?", parameters: [now, cnId])
            return database.executeUpdate("UPDATE chinese_table SET is_deleted = 1, updated_at = ? WHERE id = ?", parameters: [now, cnId])
        } else {
            _ = database.executeUpdate("DELETE FROM learning_table WHERE cn_id = ?", parameters: [cnId])
            _ = database.executeUpdate("DELETE FROM cn_en_mapping WHERE cn_id = ?", parameters: [cnId])
            return database.executeUpdate("DELETE FROM chinese_table WHERE id = ?", parameters: [cnId])
        }
    }

    func optimizeDatabase() { 
        // 在优化数据库时，可以考虑清理掉那些已经在云端同步完成且标记为 is_deleted = 1 的陈旧数据
        _ = database.executeUpdate("VACUUM") 
    }

    private func insertOrUpdateLearningRecord(cnId: Int?, enId: Int?) -> Bool {
        guard cnId != nil || enId != nil else { return false }
        var actualEnId = enId
        var actualCnId = cnId
        if cnId != nil && enId == nil {
            actualEnId = database.executeQuery("SELECT en_id FROM cn_en_mapping WHERE cn_id = ? ORDER BY en_id DESC LIMIT 1", parameters: [cnId!]).first?["en_id"] as? Int
        }
        if enId != nil && cnId == nil {
            actualCnId = database.executeQuery("SELECT cn_id FROM cn_en_mapping WHERE en_id = ? ORDER BY cn_id DESC LIMIT 1", parameters: [enId!]).first?["cn_id"] as? Int
        }
        let currentDate = getCurrentDate()
        let now = Int(Date().timeIntervalSince1970)
        var categoryType = ""
        var groupNum = 0
        if let actualEnId = actualEnId {
            if let row = database.executeQuery("SELECT type, type_num FROM english_table WHERE id = ?", parameters: [actualEnId]).first {
                categoryType = row["type"] as? String ?? ""
                groupNum = row["type_num"] as? Int ?? 0
            }
        }
        let checkResults = database.executeQuery("SELECT id FROM learning_table WHERE (cn_id = ? OR (? IS NULL AND cn_id IS NULL)) AND (en_id = ? OR (? IS NULL AND en_id IS NULL))", parameters: [actualCnId as Any, actualCnId as Any, actualEnId as Any, actualEnId as Any])
        if let learningId = checkResults.first?["id"] as? Int {
            return database.executeUpdate("UPDATE learning_table SET last_used_date = ?, count = count + 1, updated_at = ?, is_deleted = 0 WHERE id = ?", parameters: [currentDate, now, learningId])
        } else {
            return database.executeUpdate("INSERT INTO learning_table (cn_id, en_id, last_used_date, count, category_type, group_num, updated_at, is_deleted) VALUES (?, ?, ?, 1, ?, ?, ?, 0)", parameters: [actualCnId as Any, actualEnId as Any, currentDate, categoryType, groupNum, now])
        }
    }

    private func insertChineseWordIfNotExists(_ word: String, pinyin: String = "") -> Int {
        if let id = getChineseWordId(word) { return id }
        let now = Int(Date().timeIntervalSince1970)
        return Int(database.executeInsert("INSERT INTO chinese_table (word, word_trad, pinyin, pinyin_abbr, frequency, stroke, updated_at, is_deleted) VALUES (?, ?, ?, '', 1, '', ?, 0)", parameters: [word, word, pinyin, now]) ?? 0)
    }

    private func insertEnglishWordIfNotExists(_ word: String) -> Int {
        if let id = getEnglishWordId(word) { return id }
        let nextTypeNum = getNextTypeNum(for: "api")
        let phonex = Phonex.encode(word)
        let normalized = word.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: " ", with: "")
        let now = Int(Date().timeIntervalSince1970)
        return Int(database.executeInsert("INSERT INTO english_table (word, pos, meaning, ipa, example, example_cn, frequency, type, type_num, phonex, word_normalized, updated_at, is_deleted) VALUES (?, '', '', '', '', '', 1, 'api', ?, ?, ?, ?, 0)", parameters: [word, nextTypeNum, phonex, normalized, now]) ?? 0)
    }

    private func getNextTypeNum(for category: String) -> Int {
        return (database.executeQuery("SELECT MAX(type_num) as max_num FROM english_table WHERE type = ?", parameters: [category]).first?["max_num"] as? Int ?? 0) + 1
    }

    private func insertMappingIfNotExists(cnId: Int, enId: Int) -> Bool {
        if !database.executeQuery("SELECT id FROM cn_en_mapping WHERE cn_id = ? AND en_id = ?", parameters: [cnId, enId]).isEmpty { return true }
        let now = Int(Date().timeIntervalSince1970)
        return database.executeUpdate("INSERT INTO cn_en_mapping (cn_id, en_id, updated_at, is_deleted) VALUES (?, ?, ?, 0)", parameters: [cnId, enId, now])
    }

    private func insertOrUpdateLearningField(cnId: Int, englishId: Int, field: String, value: Any) -> Bool {
        let now = Int(Date().timeIntervalSince1970)
        if let recordId = database.executeQuery("SELECT id FROM learning_table WHERE cn_id = ? AND en_id = ?", parameters: [cnId, englishId]).first?["id"] as? Int {
            let val = field == "rank" ? String(describing: value) : value
            return database.executeUpdate("UPDATE learning_table SET \(field) = ?, updated_at = ? WHERE id = ?", parameters: [val, now, recordId])
        } else {
            let currentDate = getCurrentDate()
            var categoryType = "", groupNum = 0
            if let row = database.executeQuery("SELECT type, type_num FROM english_table WHERE id = ?", parameters: [englishId]).first {
                categoryType = row["type"] as? String ?? ""
                groupNum = row["type_num"] as? Int ?? 0
            }
            let baseParams: [Any] = [cnId, englishId, currentDate, categoryType, groupNum, now]
            var addFields = "", addVals = "", addParams: [Any] = []
            switch field {
            case "favorite": addFields = ", favorite"; addVals = ", ?"; addParams = [value]
            case "rank": addFields = ", rank"; addVals = ", ?"; addParams = [String(describing: value)]
            case "remind_data": addFields = ", remind_data"; addVals = ", ?"; addParams = [value]
            case "mark": addFields = ", mark"; addVals = ", ?"; addParams = [value]
            case "photo_identifier": addFields = ", photo_identifier"; addVals = ", ?"; addParams = [value]
            default: return false
            }
            return database.executeUpdate("INSERT INTO learning_table (cn_id, en_id, last_used_date, count, category_type, group_num, updated_at, is_deleted\(addFields)) VALUES (?, ?, ?, 1, ?, ?, ?, 0\(addVals))", parameters: baseParams + addParams)
        }
    }
}
