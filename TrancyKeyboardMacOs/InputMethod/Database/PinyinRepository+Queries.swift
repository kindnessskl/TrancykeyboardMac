import Foundation

extension PinyinRepository {
    func queryP(_ pinyin: String) -> [Candidate] {
        let wordCol = outputMode.wordColumn
        let sql = "SELECT id, \(wordCol) as text, pinyin, frequency, updated_at, stroke FROM chinese_table WHERE pinyin = ?"
        return parseCandidates(database.executeQuery(sql, parameters: [pinyin]))
    }

    func queryA(_ abbr: String) -> [Candidate] {
        let wordCol = outputMode.wordColumn
        let sql = "SELECT id, \(wordCol) as text, pinyin, frequency, updated_at, stroke FROM chinese_table WHERE pinyin_abbr = ? ORDER BY frequency DESC LIMIT 30"
        return parseCandidates(database.executeQuery(sql, parameters: [abbr]))
    }

    func queryPA(pinyinPrefix: String, abbr: String) -> [Candidate] {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT id, \(wordCol) as text, pinyin, frequency, updated_at, stroke 
            FROM chinese_table 
            WHERE pinyin >= ? || ' ' AND pinyin < ? || '!' 
              AND pinyin_abbr = ? 
            LIMIT 50
        """
        return parseCandidates(database.executeQuery(sql, parameters: [pinyinPrefix, pinyinPrefix, abbr]))
    }

    func queryAP(pinyinSuffix: String, pureabbr: String) -> [Candidate] {
        let wordCol = outputMode.wordColumn
        let sql = "SELECT id, \(wordCol) as text, pinyin, frequency, updated_at, stroke FROM chinese_table WHERE pinyin LIKE '% ' || ? AND pinyin_abbr = ? LIMIT 50"
        return parseCandidates(database.executeQuery(sql, parameters: [pinyinSuffix, pureabbr]))
    }


    func queryPT(_ pinyin: String) -> ([Candidate], [[String]]) {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT c.id, c.\(wordCol) as text, c.pinyin, c.frequency, c.updated_at, c.stroke, e.word as translation
            FROM chinese_table c
            LEFT JOIN cn_en_mapping m ON c.id = m.cn_id
            LEFT JOIN english_table e ON m.en_id = e.id
            WHERE c.pinyin = ?
        """
        return processJoinResults(database.executeQuery(sql, parameters: [pinyin]))
    }

    func queryAT(_ abbr: String) -> ([Candidate], [[String]]) {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT 
                c.id, 
                c.\(wordCol) AS text, 
                c.pinyin, 
                c.frequency, 
                c.updated_at, 
                c.stroke, 
                e.word AS translation
            FROM chinese_table c
            LEFT JOIN cn_en_mapping m ON c.id = m.cn_id
            LEFT JOIN english_table e ON m.en_id = e.id
            WHERE c.pinyin_abbr = ?
            ORDER BY c.frequency DESC 
            LIMIT 30
        """
        let resultSet = database.executeQuery(sql, parameters: [abbr])
        return processJoinResults(resultSet)
    }

    func queryPAT(pinyinPrefix: String, abbr: String) -> ([Candidate], [[String]]) {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT c.id, c.\(wordCol) as text, c.pinyin, c.frequency, c.updated_at, c.stroke, e.word as translation
            FROM chinese_table c
            LEFT JOIN cn_en_mapping m ON c.id = m.cn_id
            LEFT JOIN english_table e ON m.en_id = e.id
            WHERE c.pinyin >= ? || ' ' AND c.pinyin < ? || '!' 
              AND c.pinyin_abbr = ? 
            LIMIT 50
        """
        return processJoinResults(database.executeQuery(sql, parameters: [pinyinPrefix, pinyinPrefix, abbr]))
    }

    func queryAPT(pinyinSuffix: String, pureabbr: String) -> ([Candidate], [[String]]) {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT c.id, c.\(wordCol) as text, c.pinyin, c.frequency, c.updated_at, c.stroke, e.word as translation
            FROM chinese_table c
            LEFT JOIN cn_en_mapping m ON c.id = m.cn_id
            LEFT JOIN english_table e ON m.en_id = e.id
            WHERE c.pinyin LIKE '% ' || ? AND c.pinyin_abbr = ?
            LIMIT 50
        """
        return processJoinResults(database.executeQuery(sql, parameters: [pinyinSuffix, pureabbr]))
    }

    func queryAutoSuggestion(_ pinyin: String) -> ([Candidate], [[String]]) {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT c.id, c.\(wordCol) as text, c.pinyin, c.frequency, c.updated_at, c.stroke, e.word as translation
            FROM chinese_table c
            LEFT JOIN cn_en_mapping m ON c.id = m.cn_id
            LEFT JOIN english_table e ON m.en_id = e.id
            WHERE c.pinyin >= ? || ' ' AND c.pinyin < ? || '!'
              AND c.frequency > 10000
            LIMIT 1
        """
        return processJoinResults(database.executeQuery(sql, parameters: [pinyin, pinyin]))
    }

    func queryTopCandidate(_ pinyin: String) -> (Candidate, [String])? {
        let wordCol = outputMode.wordColumn
        let sql = "SELECT id, \(wordCol) as text, pinyin, frequency, updated_at, stroke FROM chinese_table WHERE pinyin = ? LIMIT 1"
        let candidates = parseCandidates(database.executeQuery(sql, parameters: [pinyin]))
        if let candidate = candidates.first {
            return (candidate, [])
        }
        return nil
    }

    func queryTopCandidateAbbr(_ abbr: String) -> (Candidate, [String])? {
        let wordCol = outputMode.wordColumn
        let sql = "SELECT id, \(wordCol) as text, pinyin, frequency, updated_at, stroke FROM chinese_table WHERE pinyin_abbr = ? LIMIT 1"
        let candidates = parseCandidates(database.executeQuery(sql, parameters: [abbr]))
        if let candidate = candidates.first {
            return (candidate, [])
        }
        return nil
    }
  
    func warmup() {
        let _ = database.executeQuery("SELECT count(*) FROM chinese_table WHERE pinyin = 'a' LIMIT 1")
        let _ = database.executeQuery("SELECT count(*) FROM english_table WHERE word = 'a' LIMIT 1")
    }
    
    func queryEnglishByPinyin(_ pinyin: String) -> ([Candidate], [[String]]) {
        let wordCol = outputMode.wordColumn
        let sql = """
            SELECT e.id, e.word as text, c.pinyin, e.frequency, e.updated_at, c.\(wordCol) as translation
            FROM chinese_table c
            INNER JOIN cn_en_mapping m ON c.id = m.cn_id
            INNER JOIN english_table e ON m.en_id = e.id
            WHERE c.pinyin = ?
        """
        return processEnglishJoinResults(database.executeQuery(sql, parameters: [pinyin]))
    }

   
    private func processEnglishJoinResults(_ results: [[String: Any]]) -> ([Candidate], [[String]]) {
        var candidates: [Candidate] = []
        var translations: [[String]] = []
        var seenTexts = Set<String>()
        let now = Int(Date().timeIntervalSince1970)
        
        for row in results {
            guard let text = row["text"] as? String else { continue }
            let pinyin = row["pinyin"] as? String ?? ""
            let freq = row["frequency"] as? Int ?? 0
            let updatedAt = row["updated_at"] as? Int ?? 0
            let trans = row["translation"] as? String ?? ""
            
            if seenTexts.contains(text) {
                if let idx = candidates.firstIndex(where: { $0.text == text }) {
                    if !translations[idx].contains(trans) && !trans.isEmpty {
                        translations[idx].append(trans)
                    }
                }
                continue
            }
            
            seenTexts.insert(text)
            candidates.append(Candidate(text: text, pinyin: pinyin, frequency: freq, updatedAt: updatedAt, strokeCount: 0))
            translations.append(trans.isEmpty ? [] : [trans])
        }
        
        let combined = zip(candidates, translations).sorted { item1, item2 in
            let c1 = item1.0, c2 = item2.0
            let score1 = Double(c1.frequency) + 200000000.0 / (1.0 + Double(now - c1.updatedAt) / 28800.0)
            let score2 = Double(c2.frequency) + 200000000.0 / (1.0 + Double(now - c2.updatedAt) / 28800.0)
            return score1 > score2
        }
        
        return (combined.map { $0.0 }, combined.map { $0.1 })
    }
}
