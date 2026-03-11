import Foundation

extension PinyinRepository {
    func getHistoryWordsByDate(_ date: String) -> [HistoryWord] {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT l.cn_id, l.en_id, l.count, l.last_used_date, l.updated_at, COALESCE(l.favorite, 0) as favorite,
            COALESCE(l.rank, 0) as rank, COALESCE(l.remind_data, '') as remind_data,
            e.word as english_word, COALESCE(c.\(wordCol), '') as chinese_word
            FROM learning_table l JOIN english_table e ON l.en_id = e.id
            LEFT JOIN chinese_table c ON l.cn_id = c.id
            WHERE (l.last_used_date = ? OR l.remind_data = ?) AND l.is_deleted = 0
            ORDER BY l.updated_at DESC, l.count DESC, l.id
        """
        return parseHistoryWords(database.executeQuery(sql, parameters: [date, date]))
    }

    func getAvailableHistoryDates() -> [String] {
        let currentDate = getCurrentDate()
        let sql = "SELECT DISTINCT last_used_date FROM learning_table WHERE ((last_used_date IS NOT NULL AND last_used_date != '') OR (remind_data IS NOT NULL AND remind_data != '')) AND is_deleted = 0 ORDER BY last_used_date DESC"
        var dates = database.executeQuery(sql).compactMap { $0["last_used_date"] as? String }
        if !dates.contains(currentDate) { dates.insert(currentDate, at: 0) }
        return dates
    }

    func getDatesWithCounts() -> [String: Int] {
        let sql = "SELECT last_used_date, COUNT(*) as count FROM learning_table WHERE last_used_date IS NOT NULL AND last_used_date != '' AND is_deleted = 0 GROUP BY last_used_date"
        var dict = [String: Int]()
        for row in database.executeQuery(sql) {
            if let date = row["last_used_date"] as? String, let count = row["count"] as? Int { dict[date] = count }
        }
        return dict
    }

    func getHistoryStats() -> HistoryStats {
        let currentDate = getCurrentDate()
        let dateSql = "SELECT last_used_date AS date_val FROM learning_table WHERE (last_used_date IS NOT NULL AND last_used_date != '' AND is_deleted = 0) UNION SELECT remind_data AS date_val FROM learning_table WHERE (remind_data IS NOT NULL AND remind_data != '' AND is_deleted = 0) ORDER BY date_val DESC"
        var dates = database.executeQuery(dateSql).compactMap { $0["date_val"] as? String }
        if !dates.contains(currentDate) { dates.insert(currentDate, at: 0) }
        let todayUsedCount = database.executeQuery("SELECT COUNT(*) as count FROM learning_table WHERE last_used_date = ? AND is_deleted = 0", parameters: [currentDate]).first?["count"] as? Int ?? 0
        let reviewCount = database.executeQuery("SELECT COUNT(*) as count FROM learning_table WHERE remind_data = ? AND is_deleted = 0", parameters: [currentDate]).first?["count"] as? Int ?? 0
        return HistoryStats(dates: dates, todayUsedCount: todayUsedCount, reviewCount: reviewCount)
    }

    func getTotalUniqueChineseWords() -> Int {
        return database.executeQuery("SELECT COUNT(DISTINCT cn_id) as total FROM learning_table WHERE cn_id IS NOT NULL AND is_deleted = 0").first?["total"] as? Int ?? 0
    }

    func getTotalUniqueEnglishWords() -> Int {
        return database.executeQuery("SELECT COUNT(DISTINCT en_id) as total FROM learning_table WHERE en_id IS NOT NULL AND is_deleted = 0").first?["total"] as? Int ?? 0
    }

    func getAllHistoryWords(limit: Int = 100, offset: Int = 0) -> [HistoryWord] {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT l.cn_id, l.en_id, l.count, l.last_used_date, l.updated_at, COALESCE(l.favorite, 0) as favorite,
            COALESCE(l.rank, 0) as rank, COALESCE(l.remind_data, '') as remind_data,
            e.word as english_word, COALESCE(c.\(wordCol), '') as chinese_word
            FROM learning_table l JOIN english_table e ON l.en_id = e.id
            LEFT JOIN chinese_table c ON l.cn_id = c.id
            WHERE ((l.last_used_date IS NOT NULL AND l.last_used_date != '') OR (l.remind_data IS NOT NULL AND l.remind_data != '')) AND l.is_deleted = 0
            ORDER BY l.updated_at DESC, l.count DESC, l.id LIMIT ? OFFSET ?
        """
        return parseHistoryWords(database.executeQuery(sql, parameters: [limit, offset]))
    }

    func getTotalAllHistoryChineseWords() -> Int {
        let sql = "SELECT COUNT(DISTINCT cn_id) as total FROM learning_table WHERE cn_id IS NOT NULL AND ((last_used_date IS NOT NULL AND last_used_date != '') OR (remind_data IS NOT NULL AND remind_data != '')) AND is_deleted = 0"
        return database.executeQuery(sql).first?["total"] as? Int ?? 0
    }

    func getTotalAllHistoryEnglishWords() -> Int {
        let sql = "SELECT COUNT(DISTINCT en_id) as total FROM learning_table WHERE en_id IS NOT NULL AND ((last_used_date IS NOT NULL AND last_used_date != '') OR (remind_data IS NOT NULL AND remind_data != '')) AND is_deleted = 0"
        return database.executeQuery(sql).first?["total"] as? Int ?? 0
    }

    func getWordsByCategoryAndGroup(_ categoryType: String, groupIndex: Int) -> [WordListItem] {
        let startRange = groupIndex * 100 + 1
        let endRange = (groupIndex + 1) * 100
        let sql = """
            SELECT e.id as en_id, e.word as english_word, e.pos, e.meaning, e.ipa, e.example, e.frequency,
            COALESCE(l.rank, '0') as rank, COALESCE(l.remind_data, '') as remind_data, COALESCE(l.favorite, 0) as favorite
            FROM english_table e LEFT JOIN (SELECT en_id, rank, remind_data, favorite, ROW_NUMBER() OVER (PARTITION BY en_id ORDER BY last_used_date DESC, id DESC) as rn FROM learning_table WHERE is_deleted = 0) l ON e.id = l.en_id AND l.rn = 1
            WHERE e.type = ? AND e.type_num >= ? AND e.type_num <= ? ORDER BY e.type_num, e.frequency DESC
        """
        return parseWordListItems(database.executeQuery(sql, parameters: [categoryType, startRange, endRange]))
    }

    
    func getTotalCount(for categoryType: String) -> Int {
        let result = database.executeQuery("SELECT COUNT(*) as total_count FROM english_table WHERE type = ?", parameters: [categoryType])
        return result.first?["total_count"] as? Int ?? 0
    }

    func getCategoryWordCounts() -> [String: Int] {
        var categoryCounts: [String: Int] = [:]
        for row in database.executeQuery("SELECT type, COUNT(*) as word_count FROM english_table GROUP BY type") {
            if let type = row["type"] as? String, let count = row["word_count"] as? Int { categoryCounts[type] = count }
        }
        return categoryCounts
    }

    func getLearningRecordsForEnglish(englishId: Int) -> [LearningRecord] {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT COALESCE(l.id, 0) as id, COALESCE(l.cn_id, 0) as cn_id, e.id as en_id, COALESCE(l.count, 0) as count,
            COALESCE(l.favorite, 0) as favorite, COALESCE(l.rank, 0) as rank, COALESCE(l.remind_data, '') as remind_data,
            COALESCE(l.mark, '') as mark, COALESCE(l.photo_identifier, '') as photo_identifier, COALESCE(l.photo_path, '') as photo_path,
            e.word as english_word, e.pos, e.meaning, e.ipa, e.example, e.example_cn, e.frequency, COALESCE(c.\(wordCol), '') as chinese_word,
            e.type as category_type, e.type_num as group_num, COALESCE(l.last_used_date, '') as last_used_date
            FROM english_table e LEFT JOIN learning_table l ON e.id = l.en_id AND l.is_deleted = 0 LEFT JOIN chinese_table c ON l.cn_id = c.id
            WHERE e.id = ? ORDER BY COALESCE(l.count, 0) DESC, COALESCE(l.last_used_date, '') DESC
        """
        return parseLearningRecords(database.executeQuery(sql, parameters: [englishId]))
    }

    func searchByEnglishKeyword(_ keyword: String) -> LearningRecord? {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT COALESCE(l.id, 0) as id, COALESCE(l.cn_id, 0) as cn_id, e.id as en_id, COALESCE(l.count, 0) as count,
            COALESCE(l.favorite, 0) as favorite, COALESCE(l.rank, 0) as rank, COALESCE(l.remind_data, '') as remind_data,
            COALESCE(l.mark, '') as mark, COALESCE(l.photo_identifier, '') as photo_identifier, COALESCE(l.photo_path, '') as photo_path,
            e.word as english_word, e.pos, e.meaning, e.ipa, e.example, e.example_cn, e.frequency, COALESCE(c.\(wordCol), '') as chinese_word,
            e.type as category_type, e.type_num as group_num, COALESCE(l.last_used_date, '') as last_used_date
            FROM english_table e LEFT JOIN learning_table l ON e.id = l.en_id AND l.is_deleted = 0 LEFT JOIN chinese_table c ON l.cn_id = c.id
            WHERE LOWER(e.word) = LOWER(?) ORDER BY e.frequency DESC LIMIT 1
        """
        return parseLearningRecords(database.executeQuery(sql, parameters: [keyword])).first
    }

    func searchEnglishWordsByKeyword(_ keyword: String) -> [LearningRecord] {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT COALESCE(l.id, 0) as id, COALESCE(l.cn_id, 0) as cn_id, e.id as en_id, COALESCE(l.count, 0) as count,
            COALESCE(l.favorite, 0) as favorite, COALESCE(l.rank, 0) as rank, COALESCE(l.remind_data, '') as remind_data,
            COALESCE(l.mark, '') as mark, COALESCE(l.photo_identifier, '') as photo_identifier, COALESCE(l.photo_path, '') as photo_path,
            e.word as english_word, e.pos, e.meaning, e.ipa, e.example, e.example_cn, e.frequency, COALESCE(c.\(wordCol), '') as chinese_word,
            e.type as category_type, e.type_num as group_num, COALESCE(l.last_used_date, '') as last_used_date
            FROM english_table e LEFT JOIN learning_table l ON e.id = l.en_id AND l.is_deleted = 0 LEFT JOIN chinese_table c ON l.cn_id = c.id
            WHERE LOWER(e.word) LIKE LOWER(?) OR LOWER(e.meaning) LIKE LOWER(?) OR LOWER(e.pos) LIKE LOWER(?)
            ORDER BY CASE WHEN LOWER(e.word) = LOWER(?) THEN 1 WHEN LOWER(e.word) LIKE LOWER(?) THEN 2 WHEN LOWER(e.meaning) LIKE LOWER(?) THEN 3 ELSE 4 END, e.frequency DESC LIMIT 50
        """
        let likeKeyword = "%\(keyword)%"
        return parseLearningRecords(database.executeQuery(sql, parameters: [likeKeyword, likeKeyword, likeKeyword, keyword, "\(keyword)%", likeKeyword]))
    }

    func getChineseWordId(_ word: String) -> Int? {
        return database.executeQuery("SELECT id FROM chinese_table WHERE word = ? OR word_trad = ?", parameters: [word, word]).first?["id"] as? Int
    }
    func getEnglishWordId(_ word: String) -> Int? {
        return database.executeQuery("SELECT id FROM english_table WHERE word = ?", parameters: [word]).first?["id"] as? Int
    }
    func findEnglishIdForChinese(_ chineseId: Int) -> Int? {
        let sql = "SELECT cem.en_id FROM cn_en_mapping cem INNER JOIN english_table et ON cem.en_id = et.id WHERE cem.cn_id = ? ORDER BY et.frequency DESC LIMIT 1"
        return database.executeQuery(sql, parameters: [chineseId]).first?["en_id"] as? Int
    }
    func getChineseWordDetails(cnId: Int) -> (pinyin: String, pinyinAbbr: String, stroke: String, frequency: Int)? {
        guard cnId > 0, let row = database.executeQuery("SELECT pinyin, pinyin_abbr, stroke, frequency FROM chinese_table WHERE id = ?", parameters: [cnId]).first else { return nil }
        return (row["pinyin"] as? String ?? "", row["pinyin_abbr"] as? String ?? "", row["stroke"] as? String ?? "", row["frequency"] as? Int ?? 0)
    }

    private func parseWordListItems(_ results: [[String: Any]]) -> [WordListItem] {
        return results.compactMap { row in
            guard let enId = row["en_id"] as? Int, let englishWord = row["english_word"] as? String, let pos = row["pos"] as? String, let meaning = row["meaning"] as? String, let example = row["example"] as? String, let frequency = row["frequency"] as? Int else { return nil }
            let ipa = row["ipa"] as? String ?? ""
            return WordListItem(enId: enId, englishWord: englishWord, pos: pos, meaning: meaning, ipa: ipa, example: example, rank: Int(row["rank"] as? String ?? "0") ?? 0, remindData: row["remind_data"] as? String ?? "", favorite: (row["favorite"] as? Int) == 1, frequency: frequency)
        }
    }

    private func parseLearningRecords(_ results: [[String: Any]]) -> [LearningRecord] {
        return results.compactMap { row in
            guard let id = row["id"] as? Int, let cnId = row["cn_id"] as? Int, let enId = row["en_id"] as? Int, let englishWord = row["english_word"] as? String, let pos = row["pos"] as? String, let meaning = row["meaning"] as? String, let example = row["example"] as? String, let exampleCn = row["example_cn"] as? String, let frequency = row["frequency"] as? Int, let count = row["count"] as? Int, let categoryType = row["category_type"] as? String, let groupNum = row["group_num"] as? Int, let lastUsedDate = row["last_used_date"] as? String else { return nil }
            let ipa = row["ipa"] as? String ?? ""
            return LearningRecord(id: id, cnId: cnId, enId: enId, englishWord: englishWord, chineseWord: row["chinese_word"] as? String ?? "", pos: pos, meaning: meaning, ipa: ipa, example: example, exampleCn: exampleCn, frequency: frequency, count: count, lastUsedDate: lastUsedDate, categoryType: categoryType, groupNum: groupNum, favorite: (row["favorite"] as? Int) == 1, rank: Int(row["rank"] as? String ?? "0") ?? 0, remindData: row["remind_data"] as? String ?? "", mark: row["mark"] as? String ?? "", photoIdentifier: row["photo_identifier"] as? String ?? "", photoPath: row["photo_path"] as? String ?? "")
        }
    }

    private func parseHistoryWords(_ results: [[String: Any]]) -> [HistoryWord] {
        let chineseTotalCount = getTotalUniqueChineseWords()
        let englishTotalCount = getTotalUniqueEnglishWords()
        return results.compactMap { row in
            guard let enId = row["en_id"] as? Int, let englishWord = row["english_word"] as? String, let count = row["count"] as? Int, let lastUsedDate = row["last_used_date"] as? String else { return nil }
            return HistoryWord(cnId: row["cn_id"] as? Int ?? 0, enId: enId, englishWord: englishWord, chineseWord: row["chinese_word"] as? String ?? "", count: count, lastUsedDate: lastUsedDate, updatedAt: row["updated_at"] as? Int ?? 0, favorite: (row["favorite"] as? Int) == 1, rank: Int(row["rank"] as? String ?? "0") ?? 0, remindData: row["remind_data"] as? String ?? "", chineseTotalCount: chineseTotalCount, englishTotalCount: englishTotalCount)
        }
    }
}
