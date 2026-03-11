import Foundation

class PinyinSegmentValidator {
    static let shared = PinyinSegmentValidator()
    private let validator = PinyinValidator.shared
    private let correctionEngine = PinyinCorrectionEngine.shared
    
    var isSlidingFuzzyEnabled: Bool = true
    var isAutoCorrectEnabled: Bool = false
    var isKeyboardCorrectEnabled: Bool = false
    
    private var segmentationCache: [String: [PinyinSegmentationResult]] = [:]
    private let maxCacheSize = 50
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .keyboardSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshSettings()
            self?.segmentationCache.removeAll()
        }
    }
    
    func refreshSettings() {
        let defaults = SharedUserDefaults.shared
        isSlidingFuzzyEnabled = defaults.bool(forKey: "isSlidingFuzzyEnabled", defaultValue: true)
        isAutoCorrectEnabled = defaults.bool(forKey: "isAutoCorrectEnabled")
        isKeyboardCorrectEnabled = defaults.bool(forKey: "isKeyboardCorrectEnabled")
    }
    
    func validateAndSegmentAll(_ input: String) -> [PinyinSegmentationResult] {
        guard !input.isEmpty else { return [] }
        let normalizedInput = input.lowercased()
        let optimalResults = findOptimalSegmentation(normalizedInput)
        
        print("--- Segmentation Results for input: \(input) ---")
        for (index, result) in optimalResults.enumerated() {
            let segmentsStr = result.segments.map { $0.text }.joined(separator: "|")
            print("Path \(index + 1): \(segmentsStr) (FullySegmented: \(result.isFullySegmented))")
        }
        return optimalResults
    }
    
    func formatRawInput(_ input: String, with segments: [PinyinSegment]) -> String {
        guard !input.isEmpty else { return "" }
        
        let lowercasedInput = input.lowercased()
        var result = ""
        let inputChars = Array(lowercasedInput)
        var lastEndIndex = 0
        
        for (i, segment) in segments.enumerated() {
            while lastEndIndex < segment.startIndex && lastEndIndex < inputChars.count {
                let char = inputChars[lastEndIndex]
                result += (char == "|" ? "'" : String(char))
                lastEndIndex += 1
            }
            
            if i > 0 && segments[i-1].isValid {
                if !result.hasSuffix("'") && !result.hasSuffix(" ") && !result.isEmpty {
                    result += " "
                }
            }
            
            if segment.startIndex < inputChars.count {
                let actualEnd = min(segment.endIndex, inputChars.count)
                if segment.startIndex < actualEnd {
                    let segmentText = String(inputChars[segment.startIndex..<actualEnd])
                    result += segmentText
                }
            }
            lastEndIndex = segment.endIndex
        }
        
        while lastEndIndex < inputChars.count {
            let char = inputChars[lastEndIndex]
            result += (char == "|" ? "'" : String(char))
            lastEndIndex += 1
        }
        
        return result
    }
    
    func findOptimalSegmentation(_ input: String) -> [PinyinSegmentationResult] {
        if let cached = segmentationCache[input] {
            return cached
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        if input.count == 1 {
            let result = handleSingleLetterInput(input)
            updateCache(input: input, results: result)
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("单字母分词耗时: \(String(format: "%.2f", duration))ms, 结果数: \(result.count)")
            return result
        }
        
        let chars = Array(input)
        let standardPaths = performBaseSegmentation(chars: chars)
        let gesturePaths = performGestureSegmentation(chars: chars)
        let rawSegmentations = standardPaths + gesturePaths
        
        var allResults: [PinyinSegmentationResult] = []
        var seenSegments = Set<String>()
        let hasAnyFuzzyEnabled = correctionEngine.hasAnyFuzzyPinyinEnabled()
        
        for segments in rawSegmentations {
            addResult(segments: segments, to: &allResults, seen: &seenSegments)
            if hasAnyFuzzyEnabled {
                let variantPaths = generateVariantPaths(segments)
                for variantSegments in variantPaths {
                    addResult(segments: variantSegments, to: &allResults, seen: &seenSegments)
                }
            }
        }
        let finalResults = sortAndFilterResults(allResults)
        updateCache(input: input, results: finalResults)
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("PERF: 标准分词耗时: \(String(format: "%.2f", duration))ms, 结果数: \(finalResults.count)")
        return finalResults
    }
    
    private func handleSingleLetterInput(_ input: String) -> [PinyinSegmentationResult] {
        let isValid = validator.isValid(input)
        let segment = PinyinSegment(text: input, isValid: isValid, startIndex: 0, endIndex: 1, sequenceNumber: 1)
        let segments = [segment]
        
        let abbr = input
        let rawLength = 1
        
        let pureAbbr = PinyinPath(pathType: .pureAbbr, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: abbr, displayText: abbr, rawLength: rawLength, isValid: true)
        
        var exactPinyin = PinyinPath(pathType: .exactPinyin, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: "", rawLength: 0, isValid: false)
        if isValid {
            exactPinyin = PinyinPath(pathType: .exactPinyin, pinyin: input, pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: input, rawLength: rawLength, isValid: true)
        }
        
        let invalidPath = PinyinPath(pathType: .exactPinyin, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: "", rawLength: 0, isValid: false)
        
        let result = PinyinSegmentationResult(
            segments: segments,
            exactPinyin: exactPinyin,
            prefixPinyinWithAbbr: invalidPath,
            abbrWithSuffixPinyin: invalidPath,
            pureAbbr: pureAbbr,
            isFullySegmented: isValid
        )
        return [result]
    }
    
    private func updateCache(input: String, results: [PinyinSegmentationResult]) {
        if segmentationCache.count >= maxCacheSize {
            if let firstKey = segmentationCache.keys.first {
                segmentationCache.removeValue(forKey: firstKey)
            }
        }
        segmentationCache[input] = results
    }
    
    private func addResult(segments: [PinyinSegment], to results: inout [PinyinSegmentationResult], seen: inout Set<String>) {
        let key = segments.map { $0.text }.joined(separator: "-")
        if seen.contains(key) { return }
        seen.insert(key)
        
        let isFullySegmented = checkIfFullySegmented(segments)
        let paths = generateAllPathTypes(segments, isFullySegmented: isFullySegmented)
        
        let result = PinyinSegmentationResult(
            segments: segments,
            exactPinyin: paths.exactPinyin,
            prefixPinyinWithAbbr: paths.prefixPinyinWithAbbr,
            abbrWithSuffixPinyin: paths.abbrWithSuffixPinyin,
            pureAbbr: paths.pureAbbr,
            isFullySegmented: isFullySegmented
        )
        results.append(result)
    }
    
    private func performGestureSegmentation(chars: [Character]) -> [[PinyinSegment]] {
        guard isSlidingFuzzyEnabled else { return [] }
        var segments: [PinyinSegment] = []
        var pos = 0
        var seq = 1
        
        while pos < chars.count {
            // Using String slice to avoid some allocation, findBestFuzzySyllable takes String
            let remaining = String(chars[pos..<chars.count])
            if let match = correctionEngine.findBestFuzzySyllable(remaining, isEnabled: isSlidingFuzzyEnabled) {
                segments.append(PinyinSegment(
                    text: match.syllable,
                    isValid: true,
                    startIndex: pos,
                    endIndex: pos + match.consumedLength,
                    sequenceNumber: seq
                ))
                pos += match.consumedLength
                seq += 1
            } else {
                let text = String(chars[pos])
                segments.append(PinyinSegment(
                    text: text,
                    isValid: validator.isValid(text),
                    startIndex: pos,
                    endIndex: pos + 1,
                    sequenceNumber: seq
                ))
                pos += 1
                seq += 1
            }
        }
        return segments.isEmpty ? [] : [segments]
    }
    
    private func performBaseSegmentation(chars: [Character]) -> [[PinyinSegment]] {
        var allPaths: [[PinyinSegment]] = []
        let charCount = chars.count
        
        func backtrack(position: Int, currentSegments: [PinyinSegment], sequenceNumber: Int) {
            if allPaths.count >= 6 { return }
            
            if position >= charCount {
                allPaths.append(currentSegments)
                return
            }
            if chars[position] == "|" {
                backtrack(position: position + 1, currentSegments: currentSegments, sequenceNumber: sequenceNumber)
                return
            }
            
            var hasExactCandidate = false
            let remainingChars = charCount - position
            
            for length in stride(from: min(6, remainingChars), through: 1, by: -1) {
                let endPos = position + length
                let originalSyllable = String(chars[position..<endPos])
                
                if validator.isValid(originalSyllable) {
                    hasExactCandidate = true
                    let segment = PinyinSegment(text: originalSyllable, isValid: true, startIndex: position, endIndex: endPos, sequenceNumber: sequenceNumber)
                    backtrack(position: endPos, currentSegments: currentSegments + [segment], sequenceNumber: sequenceNumber + 1)
                } else {
                    if isAutoCorrectEnabled {
                        let autoCorrected = correctionEngine.generateAutoCorrectionVariants(originalSyllable, isEnabled: isAutoCorrectEnabled)
                        for corrected in autoCorrected {
                            if validator.isValid(corrected) {
                                let segment = PinyinSegment(text: corrected, isValid: true, startIndex: position, endIndex: endPos, sequenceNumber: sequenceNumber)
                                backtrack(position: endPos, currentSegments: currentSegments + [segment], sequenceNumber: sequenceNumber + 1)
                            }
                        }
                    }
                    
                    if isKeyboardCorrectEnabled {
                        let keyCorrected = correctionEngine.generateOnlyKeyboardCorrectionVariants(originalSyllable, isEnabled: isKeyboardCorrectEnabled)
                        for corrected in keyCorrected {
                            if validator.isValid(corrected) {
                                let segment = PinyinSegment(text: corrected, isValid: true, startIndex: position, endIndex: endPos, sequenceNumber: sequenceNumber)
                                backtrack(position: endPos, currentSegments: currentSegments + [segment], sequenceNumber: sequenceNumber + 1)
                            }
                        }
                    }
                }
                if allPaths.count >= 6 { return }
            }
            
            if !hasExactCandidate {
                let invalidSegment = PinyinSegment(text: String(chars[position]), isValid: false, startIndex: position, endIndex: position + 1, sequenceNumber: sequenceNumber)
                backtrack(position: position + 1, currentSegments: currentSegments + [invalidSegment], sequenceNumber: sequenceNumber + 1)
            }
        }
        
        backtrack(position: 0, currentSegments: [], sequenceNumber: 1)
        return allPaths
    }
    
    private func generateVariantPaths(_ segments: [PinyinSegment]) -> [[PinyinSegment]] {
        var results: [[PinyinSegment]] = []
        var currentPath: [PinyinSegment] = []
        
        func getVariants(for segment: PinyinSegment) -> [PinyinSegment] {
            if !segment.isValid { return [segment] }
            var variants: [PinyinSegment] = [segment]
            let text = segment.text
            let fuzzy = correctionEngine.generateOnlyFuzzyPinyinVariants(text)
            for f in fuzzy {
                variants.append(PinyinSegment(text: f, isValid: true, startIndex: segment.startIndex, endIndex: segment.endIndex, sequenceNumber: segment.sequenceNumber))
            }
            return variants
        }
        
        func backtrack(index: Int) {
            if index == segments.count {
                results.append(currentPath)
                return
            }
            
            if results.count >= 50 { return }
            
            let possibleSegments = getVariants(for: segments[index])
            for seg in possibleSegments {
                currentPath.append(seg)
                backtrack(index: index + 1)
                currentPath.removeLast()
            }
        }
        
        backtrack(index: 0)
        return results
    }
    
    private func sortAndFilterResults(_ results: [PinyinSegmentationResult]) -> [PinyinSegmentationResult] {
        let fullySegmented = results.filter { $0.isFullySegmented }
        if !fullySegmented.isEmpty {
            let sorted = fullySegmented.sorted { $0.segments.count < $1.segments.count }
            return Array(sorted.prefix(10))
        }
        let partiallySegmented = results.filter { !$0.isFullySegmented }
        let sorted = partiallySegmented.sorted { (result1, result2) -> Bool in
            let validLength1 = result1.segments.filter { $0.isValid }.reduce(0) { $0 + $1.text.count }
            let validLength2 = result2.segments.filter { $0.isValid }.reduce(0) { $0 + $1.text.count }
            return validLength1 > validLength2
        }
        return Array(sorted.prefix(10))
    }
}

private func checkIfFullySegmented(_ segments: [PinyinSegment]) -> Bool {
    return !segments.contains { !$0.isValid }
}

private func generateAllPathTypes(_ segments: [PinyinSegment], isFullySegmented: Bool) -> (
    exactPinyin: PinyinPath,
    prefixPinyinWithAbbr: PinyinPath,
    abbrWithSuffixPinyin: PinyinPath,
    pureAbbr: PinyinPath
) {
    let validSegments = segments.filter { $0.isValid }
    let invalidSegments = segments.filter { !$0.isValid }
    let hasInvalidSegments = segments.contains { !$0.isValid }
    let exactPinyin = generateExactPinyin(segments, isFullySegmented: isFullySegmented)
    let invalidPath = PinyinPath(pathType: .exactPinyin, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: "", rawLength: 0, isValid: false)
    if isFullySegmented && !hasInvalidSegments && exactPinyin.isValid {
        return (exactPinyin: exactPinyin, prefixPinyinWithAbbr: invalidPath, abbrWithSuffixPinyin: invalidPath, pureAbbr: invalidPath)
    }
    let prefixPinyinWithAbbr = generatePrefixPinyinWithAbbr(validSegments, invalidSegments)
    let abbrWithSuffixPinyin = generateAbbrWithSuffixPinyin(validSegments, invalidSegments)
    let pureAbbr = generatePureAbbr(segments)
    return (exactPinyin: exactPinyin, prefixPinyinWithAbbr: prefixPinyinWithAbbr, abbrWithSuffixPinyin: abbrWithSuffixPinyin, pureAbbr: pureAbbr)
}

private func generateExactPinyin(_ segments: [PinyinSegment], isFullySegmented: Bool) -> PinyinPath {
    if isFullySegmented && !segments.contains(where: { !$0.isValid }) {
        let pinyin = segments.map { $0.text }.joined(separator: " ")
        let rawLength = segments.last?.endIndex ?? 0
        return PinyinPath(pathType: .exactPinyin, pinyin: pinyin, pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: pinyin, rawLength: rawLength, isValid: true)
    }
    return PinyinPath(pathType: .exactPinyin, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: "", rawLength: 0, isValid: false)
}

private func generatePrefixPinyinWithAbbr(_ validSegments: [PinyinSegment], _ invalidSegments: [PinyinSegment]) -> PinyinPath {
    let prefixValidSegments = validSegments.filter { v in invalidSegments.allSatisfy { $0.sequenceNumber > v.sequenceNumber } }
    guard !prefixValidSegments.isEmpty else { return PinyinPath(pathType: .prefixPinyinWithAbbr, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: "", rawLength: 0, isValid: false) }
    let pinyinPrefix = prefixValidSegments.map { $0.text }.joined(separator: " ")
    let abbrPath = generatePureAbbr(validSegments + invalidSegments)
    let abbr = abbrPath.abbr
    let a = generatePureAbbr(invalidSegments).abbr
    let displayText = [pinyinPrefix, a].filter { !$0.isEmpty }.joined(separator: " ")
    return PinyinPath(pathType: .prefixPinyinWithAbbr, pinyin: "", pinyinPrefix: pinyinPrefix, pinyinSuffix: "", abbr: abbr, displayText: displayText, rawLength: abbrPath.rawLength, isValid: !displayText.isEmpty)
}

private func generateAbbrWithSuffixPinyin(_ validSegments: [PinyinSegment], _ invalidSegments: [PinyinSegment]) -> PinyinPath {
    let suffixValidSegments = validSegments.filter { v in invalidSegments.allSatisfy { $0.sequenceNumber < v.sequenceNumber } }
    guard !suffixValidSegments.isEmpty else { return PinyinPath(pathType: .abbrWithSuffixPinyin, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: "", displayText: "", rawLength: 0, isValid: false) }
    let abbrPath = generatePureAbbr(invalidSegments + validSegments)
    let abbr = abbrPath.abbr
    let pinyinSuffix = suffixValidSegments.map { $0.text }.joined(separator: " ")
    let a = generatePureAbbr(invalidSegments).abbr
    let displayText = [a, pinyinSuffix].filter { !$0.isEmpty }.joined(separator: " ")
    return PinyinPath(pathType: .abbrWithSuffixPinyin, pinyin: "", pinyinPrefix: "", pinyinSuffix: pinyinSuffix, abbr: abbr, displayText: displayText, rawLength: abbrPath.rawLength, isValid: !displayText.isEmpty)
}

private func generatePureAbbr(_ segments: [PinyinSegment]) -> PinyinPath {
    var abbr = ""
    for s in segments {
        if s.isValid {
            if s.text.hasPrefix("zh") || s.text.hasPrefix("ch") || s.text.hasPrefix("sh") { abbr += String(s.text.prefix(2)) }
            else { abbr += String(s.text.prefix(1)) }
        } else { abbr += s.text }
    }
    let rawLength = segments.last?.endIndex ?? 0
    return PinyinPath(pathType: .pureAbbr, pinyin: "", pinyinPrefix: "", pinyinSuffix: "", abbr: abbr, displayText: abbr, rawLength: rawLength, isValid: true)
}
