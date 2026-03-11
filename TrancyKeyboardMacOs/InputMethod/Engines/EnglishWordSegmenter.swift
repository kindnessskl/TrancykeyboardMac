import Foundation
import OSLog

struct WordEntry {
    let text: String
    let weight: Double
}

class EnglishSegmenter {
    private let logger = Logger(subsystem: "com.trancy.keyboard", category: "EnglishSegmenter")
    private let minWeight: Double = 1.0
    private let maxWordLength = 20
    
    var isLoaded = true
    static let shared = EnglishSegmenter()
    private init() {}
    
    func ensureLoaded(from database: PinyinRepository) {}
    
    func segment(input: String, repository: PinyinRepository) -> [String] {
        let startTime = Date()
        let text = input.lowercased()
        let chars = Array(text)
        let n = chars.count
        if n == 0 { return [] }
        
        var possibleSubstrings: Set<String> = []
        for i in 0..<n {
            var currentStr = ""
            for j in i..<min(i + maxWordLength, n) {
                currentStr.append(chars[j])
                possibleSubstrings.insert(currentStr)
            }
        }
        
        let validSubWords = repository.queryValidSubstrings(Array(possibleSubstrings))
        if validSubWords.isEmpty { return [] }
        
        var dag: [[Int]] = Array(repeating: [], count: n)
        for i in 0..<n {
            var currentStr = ""
            for j in i..<min(i + maxWordLength, n) {
                currentStr.append(chars[j])
                if validSubWords[currentStr] != nil {
                    dag[i].append(j + 1)
                }
            }
        }
        
        var route: [(weight: Double, nextPos: Int)] = Array(repeating: (-Double.infinity, -1), count: n + 1)
        route[n] = (0.0, n)
        
        for i in stride(from: n - 1, through: 0, by: -1) {
            var bestWeight = -Double.infinity
            var bestNext = -1
            
            for nextPos in dag[i] {
                let fragment = String(chars[i..<nextPos])
                
                // 正确解包元组：避免编译错误
                let entry = validSubWords[fragment]
                let freq = entry?.freq ?? 1.0
                let dbWord = entry?.word ?? fragment
                let logFreq = log10(max(freq, 1.0))
                let len = fragment.count

                // 终极评分策略：
                var currentWeight = logFreq * 2.0 
                currentWeight += Double(len) * 3.0 // 极高长度奖励 (3.0x)，保持单词完整性
                currentWeight -= 20.0 // 极重切分惩罚 (-20.0)，防止把 mother 拆成 mot+her

                // 短语奖励：如果数据库里这原本就是一个带空格的词组，给它巨大加成
                if dbWord.contains(" ") {
                    currentWeight += 15.0
                }
                
                if len == 1 {
                    if (fragment != "i" && fragment != "a") { 
                        currentWeight -= 30.0 
                    }
                }
                
                let totalWeight = currentWeight + route[nextPos].weight
                
                if totalWeight > bestWeight {
                    bestWeight = totalWeight
                    bestNext = nextPos
                }
            }
            route[i] = (bestWeight, bestNext)
        }
        
        if route[0].weight == -Double.infinity { return [] }
        
        var result: [String] = []
        var curr = 0
        while curr < n {
            let next = route[curr].nextPos
            if next == -1 { break }
            let fragment = String(chars[curr..<next])
            if let dbWord = validSubWords[fragment]?.word {
                result.append(dbWord)
            } else {
                result.append(fragment)
            }
            curr = next
        }
        
        let duration = Date().timeIntervalSince(startTime) * 1000
        logger.debug("Segmented '\(input)' dynamically in \(String(format: "%.2f", duration))ms. Result: \(result)")
        return result
    }
    
    func segmentToCandidate(input: String, repository: PinyinRepository) -> Candidate? {
        guard input.count >= 3 else { return nil }
        let tokens = segment(input: input, repository: repository)
        guard tokens.count > 1 else { return nil }
                
        for (index, token) in tokens.enumerated() {
            let t = token.lowercased()
            if t.count == 1 {
                if (t == "i" && index > 0) || (t != "i" && t != "a") { return nil }
            }
        }
        
        for i in 0..<(tokens.count - 1) {
            if tokens[i].count == 1 && tokens[i+1].count == 1 { return nil }
        }
        
        let hasAnchorWord = tokens.contains { $0.count >= 3 }
        if !hasAnchorWord && input.count < 8 { return nil }
        
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
