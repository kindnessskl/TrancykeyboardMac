import Foundation
import OSLog

private let logger = Logger(subsystem: "com.trancy.keyboard", category: "EnglishQuery")

extension PinyinRepository {

    func queryAllEnglishCandidates(
        _ keyword: String,
        enableFuzzy: Bool,
        skipExactAndPrefix: Bool = false,
        isPrefixEnabled: Bool = true
    ) -> (
        exact: (candidate: Candidate, translations: [String], isPinyinMatch: Bool)?,
        prefix: (candidates: [Candidate], translations: [[String]]),
        fuzzy: ([Candidate], [[String]])
    ) {
        let startTime = Date()
        defer {
            let duration = Date().timeIntervalSince(startTime) * 1000
            logger.debug("queryAllEnglishCandidates for '\(keyword)' took \(String(format: "%.2f", duration))ms")
        }
    
        let lowerKeyword = keyword.lowercased()
        let capitalizedKeyword = keyword.capitalized
        let normalizedKeyword = lowerKeyword.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "'", with: "")
        
        var exactId: Int? = nil
        var exactIdSub: Int? = nil 
        struct ScoredCandidate { let id: Int; let word: String; let freq: Int; let dist: Int }
        var fuzzyScored: [ScoredCandidate] = []

        let step1Start = Date()
        if !skipExactAndPrefix {
            let exactSql = "SELECT id, word, frequency, updated_at FROM english_table WHERE word IN (?, ?) OR word_normalized = ?"
            if let exactMatch = database.executeQuery(exactSql, parameters: [lowerKeyword, capitalizedKeyword, normalizedKeyword]).first,
               let id = exactMatch["id"] as? Int {
                exactId = id
            }
        }
        logger.debug("Step 1 (Exact Main) took: \(String(format: "%.2f", Date().timeIntervalSince(step1Start) * 1000))ms")

        // 2. 前缀索引查询
        let step3Start = Date()
        var prefixItems: [(src: String, id: Int)] = []
        if !skipExactAndPrefix && isPrefixEnabled && keyword.count >= 1 {
            let sql = "SELECT top_ids FROM english_prefix_index WHERE prefix = ?"
            if let row = database.executeQuery(sql, parameters: [normalizedKeyword]).first,
               let topIdsStr = row["top_ids"] as? String {
                let parts = topIdsStr.split(separator: ",")
                for part in parts {
                    let info = part.split(separator: ":")
                    if info.count == 2, let id = Int(info[1]) {
                        prefixItems.append((src: String(info[0]), id: id))
                    }
                }
            }
        }
        logger.debug("Step 3 (Prefix Index) took: \(String(format: "%.2f", Date().timeIntervalSince(step3Start) * 1000))ms")

        // 3. 延迟查询副表 (sub_table) - 只要主表没匹配且不是跳过模式就尝试，不被前缀匹配阻断
        let stepSubStart = Date()
        if exactId == nil && !skipExactAndPrefix {
             let subExactSql = "SELECT id FROM sub_english_table WHERE word = ? LIMIT 1"
             if let subMatch = database.executeQuery(subExactSql, parameters: [normalizedKeyword]).first,
                let id = subMatch["id"] as? Int {
                 exactIdSub = id
             }
        }
        let subDuration = Date().timeIntervalSince(stepSubStart) * 1000
        logger.debug("Step 3.5 (Sub Table Exact) took: \(String(format: "%.2f", subDuration))ms")

            print(" [Performance] Sub table query for '\(normalizedKeyword)' took \(String(format: "%.2f", subDuration))ms")
        

        // 4. 模糊匹配
        let step2Start = Date()
        if enableFuzzy && keyword.count > 2 {
            if !(skipExactAndPrefix && keyword.count > 8) {
                let phonexCode = Phonex.encode(keyword)
                if phonexCode.count >= 1 {
                    let phonexSql = "SELECT id, word, frequency, updated_at FROM english_table WHERE phonex = ?"
                    let phonexResults = database.executeQuery(phonexSql, parameters: [phonexCode])
                    
                    for row in phonexResults {
                        guard let id = row["id"] as? Int,
                              let word = row["word"] as? String,
                              let freq = row["frequency"] as? Int else { continue }
                        if id == exactId { continue }
                        if abs(word.count - keyword.count) <= 2 {
                            let dist = keyword.damerauLevenshteinDistance(to: word, limit: 2)
                            if dist <= 2 { fuzzyScored.append(ScoredCandidate(id: id, word: word, freq: freq, dist: dist)) }
                        }
                    }
                    if !fuzzyScored.isEmpty {
                        fuzzyScored.sort { $0.dist != $1.dist ? $0.dist < $1.dist : $0.freq > $1.freq }
                        fuzzyScored = Array(fuzzyScored.prefix(5))
                    }
                }
            }
        }
        logger.debug("Step 2 (Fuzzy) took: \(String(format: "%.2f", Date().timeIntervalSince(step2Start) * 1000))ms")

        let mainIds = Set(prefixItems.filter { $0.src == "M" }.map { $0.id } + 
                         (exactId != nil ? [exactId!] : []) + 
                         fuzzyScored.map { $0.id })
        let subIds = Set(prefixItems.filter { $0.src == "S" }.map { $0.id } +
                         (exactIdSub != nil ? [exactIdSub!] : []))

        if mainIds.isEmpty && subIds.isEmpty { return (nil, ([], []), ([], [])) }

        var candMapM: [Int: Candidate] = [:]
        var transMapM: [Int: [String]] = [:]
        var candMapS: [Int: Candidate] = [:]

        if !mainIds.isEmpty {
            let idsStr = mainIds.map { String($0) }.joined(separator: ",")
            let wordCol = outputMode.wordColumn
            let transSql = """
                SELECT e.id, e.word as text, e.word as pinyin, e.frequency, e.updated_at, c.\(wordCol) as translation
                FROM english_table e
                LEFT JOIN cn_en_mapping m ON e.id = m.en_id
                LEFT JOIN chinese_table c ON m.cn_id = c.id
                WHERE e.id IN (\(idsStr))
            """
            for row in database.executeQuery(transSql) {
                guard let id = row["id"] as? Int else { continue }
                if candMapM[id] == nil {
                    candMapM[id] = Candidate(
                        text: row["text"] as! String,
                        pinyin: row["pinyin"] as! String,
                        frequency: row["frequency"] as? Int ?? 0,
                        updatedAt: row["updated_at"] as? Int ?? 0,
                        strokeCount: 0
                    )
                }
                if let t = row["translation"] as? String {
                    if transMapM[id]?.count ?? 0 < 1 { transMapM[id, default: []].append(t) }
                }
            }
        }

        // B. 从副表查询信息（无翻译，仅单词）
        if !subIds.isEmpty {
            let subIdsStr = subIds.map { String($0) }.joined(separator: ",")
            let subSql = "SELECT id, word FROM sub_english_table WHERE id IN (\(subIdsStr))"
            for row in database.executeQuery(subSql) {
                if let id = row["id"] as? Int, let word = row["word"] as? String {
                    candMapS[id] = Candidate(text: word, pinyin: word, frequency: 0, strokeCount: 0)
                }
            }
        }

        // 组装结果
        var exactRes: (Candidate, [String], Bool)? = nil
        if let eid = exactId, let c = candMapM[eid] {
            exactRes = (c, transMapM[eid] ?? [], false)
        } else if let esid = exactIdSub, let c = candMapS[esid] {
            exactRes = (c, [], false)
        }
        
        let now = Int(Date().timeIntervalSince1970)
        func getScore(_ c: Candidate) -> Double {
            return Double(c.frequency) + 200000000.0 / (1.0 + Double(now - c.updatedAt) / 28800.0)
        }

        var pItems = prefixItems.compactMap { item -> (Candidate, [String])? in
            if item.src == "M" {
                if let c = candMapM[item.id], item.id != exactId {
                    return (c, transMapM[item.id] ?? [])
                }
            } else {
                if let c = candMapS[item.id], item.id != exactIdSub {
                    return (c, [])
                }
            }
            return nil
        }
        pItems.sort { getScore($0.0) > getScore($1.0) }
        
        let pCands = pItems.map { $0.0 }
        let pTrans = pItems.map { $0.1 }
        
        var fItems = fuzzyScored.compactMap { f -> (Candidate, [String])? in
            if let c = candMapM[f.id] {
                return (c, transMapM[f.id] ?? [])
            }
            return nil
        }
        fItems.sort { getScore($0.0) > getScore($1.0) }
        
        let fCands = fItems.map { $0.0 }
        let fTrans = fItems.map { $0.1 }

        return (exactRes, (pCands, pTrans), (fCands, fTrans))
    }

    // --- 动态分词支持：查询一组子串中哪些是合法单词 ---
    func queryValidSubstrings(_ substrings: [String]) -> [String: (word: String, freq: Double)] {
        guard !substrings.isEmpty else { return [:] }
        let now = Int(Date().timeIntervalSince1970)

        let placeholders = Array(repeating: "?", count: substrings.count).joined(separator: ",")
        let sql = "SELECT word, word_normalized, frequency, updated_at FROM english_table WHERE word_normalized IN (\(placeholders))"
        
        let results = database.executeQuery(sql, parameters: substrings)
        var dict: [String: (word: String, freq: Double)] = [:]
        
        for row in results {
            guard let norm = row["word_normalized"] as? String,
                  let word = row["word"] as? String,
                  let freq = row["frequency"] as? Int else { continue }
            
            let updatedAt = row["updated_at"] as? Int ?? 0
            let score = Double(freq) + 200000000.0 / (1.0 + Double(now - updatedAt) / 28800.0)
            
            if dict[norm] == nil || score > dict[norm]!.freq {
                dict[norm] = (word: word, freq: score)
            }
        }
        return dict
    }
}
