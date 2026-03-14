import Foundation

class InputQueryService {
    private let repository = PinyinRepository.shared
    private let standardSegmenter = PinyinSegmentValidator.shared
    private let doublePinyinConverter = DoublePinyinFlypy.shared
    
    var isDoublePinyinEnabled: Bool = false
    var isEmojiEnabled: Bool = false
    var isSymbolsEnabled: Bool = false
    var isAutoSplitEnabled: Bool = false
    var isEnglishLookupEnabled: Bool = false
    var isEnglishFuzzyLookupEnabled: Bool = false
    var isEnglishPrefixLookupEnabled: Bool = true
    var isChineseLookupEnabled: Bool = true
    var isAutoSuggestionEnabled: Bool = false
    var onExactPinyinMatch: (([Candidate], [[String]]?) -> Void)?
    
    private struct EnglishQueryState {
        var lastInput: String = ""
        var consecutiveFailures: Int = 0
        var skipExactAndPrefix: Bool = false
    }
    private var lastEnglishQueryState = EnglishQueryState()

    private struct ChineseQueryState {
        var lastInput: String = ""
        var consecutiveNoExactPinyin: Int = 0
        var skipChinese: Bool = false
    }
    private var lastChineseQueryState = ChineseQueryState()
    
    private var emojiMap: [String: [String]] = [:]
    private var symbolsMap: [String: [String]] = [:]
    
    init() {
        preloadResources()
    }
    
    func resetQueryState() {
        lastChineseQueryState = ChineseQueryState()
        lastEnglishQueryState = EnglishQueryState()
    }
    
    private func preloadResources() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            _ = self.standardSegmenter
            self.repository.warmup()
            self.loadEmojiMap()
            self.loadSymbolsMap()
            EnglishSegmenter.shared.ensureLoaded(from: self.repository)
        }
    }
    
    private func loadEmojiMap() {
        guard let path = Bundle.main.path(forResource: "emoji_map", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] else {
            print("Warning: Could not load emoji_map.json")
            return
        }
        self.emojiMap = json
    }
    
    private func loadSymbolsMap() {
        guard let path = Bundle.main.path(forResource: "symbols_map", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] else {
            print("Warning: Could not load symbols_map.json")
            return
        }
        self.symbolsMap = json
    }
    
    func normalizeInput(_ input: String) -> String {
        guard isDoublePinyinEnabled && !input.isEmpty else {
            return input
        }
        
        let fullPinyinInput = doublePinyinConverter.convertToFullPinyin(input)
        return fullPinyinInput
    }
    
    func segmentInput(_ input: String) -> ([PinyinPath]) {
        let results = segmentWithStandardMode(input)
        var paths: [PinyinPath] = []
        for result in results {
            if result.exactPinyin.isValid { paths.append(result.exactPinyin) }
            if result.prefixPinyinWithAbbr.isValid { paths.append(result.prefixPinyinWithAbbr) }
            if result.abbrWithSuffixPinyin.isValid { paths.append(result.abbrWithSuffixPinyin) }
            if result.pureAbbr.isValid { paths.append(result.pureAbbr) }
        }
        return paths
    }
    func segmentWithStandardMode(_ input: String) -> [PinyinSegmentationResult] {
        if lastChineseQueryState.skipChinese {
            let segment = PinyinSegment(
                text: input,
                isValid: false,
                startIndex: 0,
                endIndex: input.count,
                sequenceNumber: 1
            )
            
            let rawPath = PinyinPath(
                pathType: .pureAbbr,
                pinyin: "",
                pinyinPrefix: "",
                pinyinSuffix: "",
                abbr: input.replacingOccurrences(of: "|", with: ""),
                displayText: input.replacingOccurrences(of: "|", with: "'"),
                rawLength: input.count,
                isValid: true
            )
            
            let invalidPath = PinyinPath(pathType: .exactPinyin, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: "", rawLength: 0, isValid: false)
            
            let result = PinyinSegmentationResult(
                segments: [segment],
                exactPinyin: invalidPath,
                prefixPinyinWithAbbr: invalidPath,
                abbrWithSuffixPinyin: invalidPath,
                pureAbbr: rawPath,
                isFullySegmented: false
            )
            return [result]
        }
        return standardSegmenter.validateAndSegmentAll(input)
    }
    func executeSmartQuery(_ input: String, segmentationResults: [PinyinSegmentationResult], inputMode: InputMode) -> QueryStrategyResult {
        if segmentationResults.isEmpty {
            return QueryStrategyResult(candidates: [], translations: [])
        }
        
        let cleanInput = input.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: " ", with: "")
        var allPaths: [PinyinPath] = []
        for result in segmentationResults {
            let paths = [result.exactPinyin, result.prefixPinyinWithAbbr, result.abbrWithSuffixPinyin, result.pureAbbr]
            allPaths.append(contentsOf: paths.filter { $0.isValid })
        }
        
        let hasExactPinyin = allPaths.contains { $0.pathType == .exactPinyin }
        updateCircuitBreakerState(cleanInput: cleanInput, hasExactPinyin: hasExactPinyin)
        
        var finalCandidates: [Candidate] = []
        var finalTranslations: [[String]] = []
        
        // 1. 中文或“拼音搜英文”查询
        if isChineseLookupEnabled {
            if !lastChineseQueryState.skipChinese {
                let chineseResult = queryChineseCandidates(input: input, allPaths: allPaths, inputMode: inputMode)
                finalCandidates.append(contentsOf: chineseResult.candidates)
                finalTranslations.append(contentsOf: chineseResult.translations ?? [])
            }
        } else {
            // 中文搜索关闭时，完全无视 skipChinese 状态，直接反查英文
            let pinyinEnglishResult = queryEnglishFromPinyinPaths(allPaths: allPaths)
            finalCandidates.append(contentsOf: pinyinEnglishResult.candidates)
            finalTranslations.append(contentsOf: pinyinEnglishResult.translations ?? [])
        }
        
        if isEnglishLookupEnabled && !input.isEmpty {
            let englishResult = queryEnglishCandidates(input: cleanInput, hasExactPinyin: hasExactPinyin)
            
            let insertIndex = hasExactPinyin ? min(1, finalCandidates.count) : 0
            for (i, candidate) in englishResult.candidates.enumerated() {
                let idx = min(insertIndex + i, finalCandidates.count)
                finalCandidates.insert(candidate, at: idx)
                finalTranslations.insert(englishResult.translations?[i] ?? [], at: idx)
            }

            if englishResult.candidates.isEmpty && !hasExactPinyin {
                if let segmentedCand = EnglishSegmenter.shared.segmentToCandidate(input: cleanInput) {
                    let idx = min(insertIndex, finalCandidates.count)
                    finalCandidates.insert(segmentedCand, at: idx)
                    finalTranslations.insert([], at: idx)
                }
            }
        }

        if isAutoSuggestionEnabled && isChineseLookupEnabled {
            let bestPinyin = allPaths.first(where: { $0.pathType == .exactPinyin })?.pinyin ?? ""
            if bestPinyin.contains(" ") {
                let (sCandidates, sTranslations) = repository.queryAutoSuggestion(bestPinyin)
                if let suggested = sCandidates.first, let trans = sTranslations.first {
                    if !finalCandidates.contains(where: { $0.text == suggested.text }) {
                        let insertIndex = min(2, finalCandidates.count)
                        finalCandidates.insert(suggested, at: insertIndex)
                        finalTranslations.insert(trans, at: insertIndex)
                    }
                }
            }
        }
        
        // 5. 符号与表情注入
        applyInjections(to: &finalCandidates, translations: &finalTranslations)
        
        return QueryStrategyResult(
            candidates: finalCandidates,
            translations: finalTranslations.isEmpty ? nil : finalTranslations
        )
    }

    private func queryEnglishFromPinyinPaths(allPaths: [PinyinPath]) -> QueryStrategyResult {
        var candidates: [Candidate] = []
        var translations: [[String]] = []

        // 仅保留全拼精确匹配的路径 (exactPinyin)
        let exactPaths = allPaths.filter { $0.pathType == .exactPinyin }

        for path in exactPaths {
            let result = repository.queryEnglishByPinyin(path.pinyin)
            
            var cands = result.0
            for i in 0..<cands.count {
                cands[i].matchedLength = path.rawLength
            }
            
            candidates.append(contentsOf: cands)
            translations.append(contentsOf: result.1)
        }
        return QueryStrategyResult(candidates: candidates, translations: translations)
    }

    private func updateCircuitBreakerState(cleanInput: String, hasExactPinyin: Bool) {
        // 重置判断：如果输入变短，重置熔断
        if cleanInput.count < lastChineseQueryState.lastInput.count {
            lastChineseQueryState.skipChinese = false
            lastChineseQueryState.consecutiveNoExactPinyin = 0
        }
        if cleanInput.count < lastEnglishQueryState.lastInput.count {
            lastEnglishQueryState.skipExactAndPrefix = false
            lastEnglishQueryState.consecutiveFailures = 0
        }
        
        lastChineseQueryState.lastInput = cleanInput
        lastEnglishQueryState.lastInput = cleanInput
        
        // 中文熔断逻辑：连续多次没有精确拼音匹配，且英文意图明显，则跳过中文查询
        let hasEnglishIntent = lastEnglishQueryState.consecutiveFailures == 0
        if !hasExactPinyin && hasEnglishIntent {
            lastChineseQueryState.consecutiveNoExactPinyin += 1
            if lastChineseQueryState.consecutiveNoExactPinyin >= 5 {
                lastChineseQueryState.skipChinese = true
            }
        } else {
            lastChineseQueryState.skipChinese = false
            lastChineseQueryState.consecutiveNoExactPinyin = 0
        }
    }

    private func queryChineseCandidates(input: String, allPaths: [PinyinPath], inputMode: InputMode) -> QueryStrategyResult {
        var candidates: [Candidate] = []
        var translations: [[String]] = []
        var hasQueriedNonExact = false
        
        for path in allPaths {
            if path.pathType != .exactPinyin {
                if hasQueriedNonExact { continue }
                hasQueriedNonExact = true
            }
            
            let queryResult = executeQueryForPath(path, input: input, inputMode: inputMode)
            candidates.append(contentsOf: queryResult.candidates)
            translations.append(contentsOf: queryResult.translations ?? Array(repeating: [], count: queryResult.candidates.count))
        }
        
        // 排序
        if !candidates.isEmpty {
            let now = Int(Date().timeIntervalSince1970)
            let combined = zip(candidates, translations).map { ($0, $1) }
            
            let scoredItems = combined.map { (item) -> ((Candidate, [String]), Double) in
                let c = item.0
                let baseScore = log(Double(max(1, c.frequency)))
                var recencyScore = 0.0
                if c.updatedAt > 0 {
                    let diff = Double(max(0, now - c.updatedAt))
                    recencyScore = 50.0 * exp(-diff / 3600.0) + 10.0 * exp(-diff / 259200.0)
                }
                return (item, baseScore + recencyScore)
            }
            
            let sorted = scoredItems.sorted { $0.1 > $1.1 }.map { $0.0 }
            candidates = sorted.map { $0.0 }
            translations = sorted.map { $0.1 }
        }
        
        if candidates.isEmpty, let firstPath = allPaths.first {
            let firstSyllable = firstPath.displayText.components(separatedBy: " ").first ?? ""
            if !firstSyllable.isEmpty {
                let (qC, qT) = repository.queryPT(firstSyllable)
                for (i, cand) in qC.enumerated() where cand.type == .character {
                    candidates.append(cand)
                    translations.append(qT[i])
                }
            }
            
            if isAutoSplitEnabled, let (splitCand, splitTrans) = composeCandidate(from: firstPath) {
                candidates.insert(splitCand, at: 0)
                translations.insert(splitTrans, at: 0)
            }
        }
        
        return QueryStrategyResult(candidates: candidates, translations: translations)
    }

    private func queryEnglishCandidates(input: String, hasExactPinyin: Bool) -> QueryStrategyResult {
        let shouldQueryExactAndPrefix = !lastEnglishQueryState.skipExactAndPrefix
        let (exact, prefix, fuzzyTuple) = repository.queryAllEnglishCandidates(
            input, 
            enableFuzzy: isEnglishFuzzyLookupEnabled,
            skipExactAndPrefix: !shouldQueryExactAndPrefix,
            isPrefixEnabled: isEnglishPrefixLookupEnabled
        )
        
        if shouldQueryExactAndPrefix {
            if exact == nil && prefix.candidates.isEmpty {
                lastEnglishQueryState.consecutiveFailures += 1
                if lastEnglishQueryState.consecutiveFailures >= 4 {
                    lastEnglishQueryState.skipExactAndPrefix = true
                }
            } else {
                lastEnglishQueryState.consecutiveFailures = 0
                lastEnglishQueryState.skipExactAndPrefix = false
            }
        }
        
        var candidates: [Candidate] = []
        var translations: [[String]] = []
        
        // 1. 精确匹配
        if let (candidate, translation, _) = exact {
            candidates.append(candidate)
            translations.append(translation)
        }
        
        // 3. 前缀匹配
        let (prefixCands, prefixTrans) = prefix
        candidates.append(contentsOf: prefixCands)
        translations.append(contentsOf: prefixTrans)
        
        // 4. 模糊匹配
        if isEnglishFuzzyLookupEnabled {
            let (fuzzyCands, fuzzyTrans) = fuzzyTuple
            candidates.append(contentsOf: fuzzyCands)
            translations.append(contentsOf: fuzzyTrans)
        }
        
        return QueryStrategyResult(candidates: candidates, translations: translations)
    }

    private func applyInjections(to candidates: inout [Candidate], translations: inout [[String]]) {
        if isEmojiEnabled {
            injectFromMap(emojiMap, to: &candidates, translations: &translations, type: "emoji")
        }
        if isSymbolsEnabled {
            injectFromMap(symbolsMap, to: &candidates, translations: &translations, type: "symbols")
        }
    }

    private func injectFromMap(_ map: [String: [String]], to candidates: inout [Candidate], translations: inout [[String]], type: String) {
        if map.isEmpty { return }
        var injections: [(candidate: Candidate, index: Int)] = []
        for i in 0..<min(10, candidates.count) {
            let word = candidates[i].text
            if let items = map[word], let firstItem = items.first {
                if !candidates.contains(where: { $0.text == firstItem }) {
                    let c = Candidate(text: firstItem, pinyin: type, frequency: 0, type: .word, strokeCount: 0)
                    injections.append((c, min(i + 1, candidates.count)))
                }
            }
        }
        for injection in injections.reversed() {
            candidates.insert(injection.candidate, at: injection.index)
            translations.insert([], at: injection.index)
        }
    }
    
    func executeQueryForPath(_ path: PinyinPath, input: String, inputMode: InputMode) -> QueryStrategyResult {
        let needTranslations = inputMode == .chinesePreview
        
        var candidates: [Candidate] = []
        var translations: [[String]]? = nil
        
        switch path.pathType {
        case .exactPinyin:
            if needTranslations {
                let (qC, qT) = repository.queryPT(path.pinyin)
                candidates = qC
                translations = qT
            } else {
                candidates = repository.queryP(path.pinyin)
            }
            onExactPinyinMatch?(candidates, translations)
            
        case .prefixPinyinWithAbbr:
            if needTranslations {
                let (qC, qT) = repository.queryPAT(pinyinPrefix: path.pinyinPrefix, abbr: path.abbr)
                candidates = qC
                translations = qT
            } else {
                candidates = repository.queryPA(pinyinPrefix: path.pinyinPrefix, abbr: path.abbr)
            }
            
        case .abbrWithSuffixPinyin:
            if needTranslations {
                let (qC, qT) = repository.queryAPT(pinyinSuffix: path.pinyinSuffix,pureabbr: path.abbr)
                candidates = qC
                translations = qT
            } else {
                candidates = repository.queryAP(pinyinSuffix: path.pinyinSuffix,pureabbr: path.abbr)
            }
            
        case .pureAbbr:
            if needTranslations {
                let (qC, qT) = repository.queryAT(path.abbr)
                candidates = qC
                translations = qT
            } else {
                candidates = repository.queryA(path.abbr)
            }
        }
        
        for i in 0..<candidates.count {
            candidates[i].matchedLength = path.rawLength
        }
        
        return QueryStrategyResult(
            candidates: candidates,
            translations: translations
        )
    }
    
    func querySingleCandidates(pinyin: String) -> [Candidate] {
        let (candidates, translations) = repository.queryPT(pinyin)
        let filtered = candidates.filter { $0.type == .character }
        
        var filteredTranslations: [[String]] = []
        for (i, c) in candidates.enumerated() {
            if c.type == .character {
                filteredTranslations.append(translations[i])
            }
        }
        onExactPinyinMatch?(filtered, filteredTranslations)
        return filtered
    }
    
   
    private func composeCandidate(from path: PinyinPath) -> (Candidate, [String])? {
        let syllables = path.displayText.components(separatedBy: " ").filter { !$0.isEmpty }
        if syllables.isEmpty { return nil }
        
        switch path.pathType {
        case .exactPinyin:
            if let res = solveSplit(syllables, isAbbr: false) {
                return (res.0, res.1)
            }
        case .prefixPinyinWithAbbr:
            let pSylls = path.pinyinPrefix.components(separatedBy: " ").filter { !$0.isEmpty }
            let pCount = pSylls.count
            let lSylls = Array(syllables.prefix(pCount))
            let rSylls = Array(syllables.suffix(from: pCount))
            if let l = solveSplit(lSylls, isAbbr: false),
               let r = solveSplit(rSylls, isAbbr: true) {
                return combine(l.0, r.0, translation: l.1)
            }
        case .abbrWithSuffixPinyin:
            let sSylls = path.pinyinSuffix.components(separatedBy: " ").filter { !$0.isEmpty }
            let sCount = sSylls.count
            let lSylls = Array(syllables.prefix(syllables.count - sCount))
            let rSylls = Array(syllables.suffix(sCount))
            if let l = solveSplit(lSylls, isAbbr: true),
               let r = solveSplit(rSylls, isAbbr: false) {
                return combine(l.0, r.0, translation: l.1)
            }
        case .pureAbbr:
            if let res = solveSplit(syllables, isAbbr: true) {
                return (res.0, res.1)
            }
        }
        return nil
    }
    
    private func solveSplit(_ syllables: [String], isAbbr: Bool) -> (Candidate, [String], Int)? {
        if syllables.isEmpty { return nil }
        guard syllables.count <= 10 else { return nil }
        let key = isAbbr ? syllables.joined() : syllables.joined(separator: " ")
        
        let result = isAbbr ? repository.queryTopCandidateAbbr(key) : repository.queryTopCandidate(key)
        
        if let (cand, trans) = result {
            return (cand, trans, 1)
        }
        
        if syllables.count == 1 { return nil }
        
        var bestCombined: (Candidate, [String], Int)? = nil
        
        for i in 1..<syllables.count {
            let leftSyllables = Array(syllables[0..<i])
            let rightSyllables = Array(syllables[i...])
            
            if let l = solveSplit(leftSyllables, isAbbr: isAbbr),
                let r = solveSplit(rightSyllables, isAbbr: isAbbr) {
                
                let currentCount = l.2 + r.2
                let (combinedCand, _) = combine(l.0, r.0, translation: l.1)
                
                if let best = bestCombined {
                    if currentCount < best.2 {
                        bestCombined = (combinedCand, l.1, currentCount)
                    } else if currentCount == best.2 && combinedCand.frequency > best.0.frequency {
                        bestCombined = (combinedCand, l.1, currentCount)
                    }
                } else {
                    bestCombined = (combinedCand, l.1, currentCount)
                }
            }
        }
        return bestCombined
    }
    
    private func combine(_ left: Candidate, _ right: Candidate, translation: [String]) -> (Candidate, [String]) {
        let combinedFrequency = min(left.frequency, right.frequency)
        let newCand = Candidate(
            text: left.text + right.text,
            pinyin: left.pinyin + " " + right.pinyin,
            frequency: combinedFrequency,
            type: .word,
            strokeCount: 0,
            matchedLength: left.matchedLength + right.matchedLength
        )
        return (newCand, translation)
    }
}
