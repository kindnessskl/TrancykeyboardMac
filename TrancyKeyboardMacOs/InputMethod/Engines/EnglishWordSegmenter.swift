import Foundation
import OSLog

struct WordEntry {
    let text: String
    let frequency: Double
    let weight: Double
}

class EnglishSegmenter {
    private let logger = Logger(subsystem: "com.trancy.keyboard", category: "EnglishSegmenter")
    private var dictionary: [String: WordEntry] = [:]
    private let minWeight: Double = -100.0
    private let maxWordLength = 20
    
    // 标记是否加载完成
    var isLoaded = false
    private let lock = NSLock()

    static let shared = EnglishSegmenter()

    private init() {}

    func ensureLoaded(from database: PinyinRepository) {
        if !isLoaded {
            loadDictionary(from: database)
        }
    }

    func loadDictionary(from database: PinyinRepository) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isLoaded else { return }
        
        let startTime = Date()
        let rawData = database.fetchEnglishWordEntries(limit: 50000)

        let totalFreq = max(rawData.values.reduce(0.0) { $0 + $1.freq }, 1.0)
        
        var tempDict: [String: WordEntry] = [:]
        for (normalized, data) in rawData {
            let currentFreq = max(data.freq, 0.1)
            let weight = log(currentFreq / totalFreq)
            tempDict[normalized] = WordEntry(
                text: data.original,
                frequency: data.freq,
                weight: weight
            )
        }
        
        self.dictionary = tempDict
        self.isLoaded = true
        
        let duration = Date().timeIntervalSince(startTime) * 1000
        logger.info("Dictionary loaded: \(self.dictionary.count) entries. Time: \(String(format: "%.2f", duration))ms")
    }

    func segment(input: String) -> [String] {
        guard isLoaded else { return [] }
        
        let startTime = Date()
        let text = input.lowercased()
        let chars = Array(text)
        let n = chars.count
        if n == 0 { return [] }

        // --- 1. DAG 构建 ---
        var dag: [[Int]] = Array(repeating: [], count: n)
        for i in 0..<n {
            var currentStr = ""
            for j in i..<min(i + maxWordLength, n) {
                currentStr.append(chars[j])
                if dictionary[currentStr] != nil {
                    dag[i].append(j + 1)
                }
            }
        }

        // --- 2. Viterbi 动态规划 (带优化评分) ---
        var route: [(weight: Double, nextPos: Int)] = Array(repeating: (-Double.infinity, -1), count: n + 1)
        route[n] = (0.0, n)

        // 评分系数：可根据实际体感微调
        let lengthBonusPerChar: Double = 3.5  // 单词每长一个字符奖励 3.5 分
        let splitPenalty: Double = -15.0     // 每多切分出一个单词，扣除 15 分

        for i in stride(from: n - 1, through: 0, by: -1) {
            var bestWeight = -Double.infinity
            var bestNext = -1
            
            for nextPos in dag[i] {
                let fragment = String(chars[i..<nextPos])
                guard let dictEntry = dictionary[fragment] else { continue }
                
                // 评分公式 = 词频 log 概率 + 长度奖励 + 切分惩罚
                let currentWordWeight = dictEntry.weight 
                                      + (Double(fragment.count) * lengthBonusPerChar)
                                      + splitPenalty
                
                let totalWeight = currentWordWeight + route[nextPos].weight
                
                if totalWeight > bestWeight {
                    bestWeight = totalWeight
                    bestNext = nextPos
                }
            }
            route[i] = (bestWeight, bestNext)
        }

        if route[0].weight == -Double.infinity {
            return []
        }

        // --- 3. 回溯 ---
        var result: [String] = []
        var curr = 0
        while curr < n {
            let next = route[curr].nextPos
            if next == -1 { break }
            let fragment = String(chars[curr..<next])
            result.append(dictionary[fragment]?.text ?? fragment)
            curr = next
        }
        
        let duration = Date().timeIntervalSince(startTime) * 1000
        logger.debug("Segmented '\(input)' strictly in \(String(format: "%.2f", duration))ms. Result: \(result)")
        return result
    }

    func segmentToCandidate(input: String) -> Candidate? {
        guard input.count >= 3 else { return nil }
        let tokens = segment(input: input)
        guard tokens.count > 1 else { return nil }
                
        // 过滤：如果输入比较短，则要求必须包含一个“实词”（锚点词）
        // 如果输入很长 (>= 10)，则信任 Viterbi 的结果，放宽锚点限制
        if input.count < 10 {
            let hasAnchorWord = tokens.contains { $0.count >= 3 }
            if !hasAnchorWord { return nil }
        }
        
        // 排除掉不合理的极短词拆分 (除了 "i", "a")
        for (index, token) in tokens.enumerated() {
            let t = token.lowercased()
            if t.count == 1 {
                if (t == "i" && index > 0) || (t != "i" && t != "a") { return nil }
            }
        }
        
        // 禁止连续的单字符单词 (如 "a i" 是合法的，但 "b c" 不合法)
        for i in 0..<(tokens.count - 1) {
            if tokens[i].count == 1 && tokens[i+1].count == 1 { return nil }
        }
        
        let combinedText = tokens.joined(separator: " ")
        logger.info("English Dynamic Segment Success: '\(input)' -> '\(combinedText)'")
        
        return Candidate(
            text: combinedText,
            pinyin: input,
            frequency: 100,
            type: .word,
            strokeCount: 0,
            matchedLength: input.count
        )
    }
}
