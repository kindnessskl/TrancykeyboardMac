import Foundation

extension PinyinCorrectionEngine {
    
    private var strongInitials: Set<Character> {
        return ["b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s", "y", "w"]
    }

    private func keyboardRow(for char: Character) -> Int {
        switch char {
        case "q","w","e","r","t","y","u","i","o","p": return 1
        case "a","s","d","f","g","h","j","k","l": return 2
        case "z","x","c","v","b","n","m": return 3
        default: return 0
        }
    }

    private func isMiddleRowPassThrough(_ chars: [Character], at index: Int) -> Bool {
        guard index > 0 && index < chars.count - 1 else { return false }
        let prevRow = keyboardRow(for: chars[index-1])
        let currRow = keyboardRow(for: chars[index])
        let nextRow = keyboardRow(for: chars[index+1])
        
        return currRow == 2 && ((prevRow == 1 && nextRow == 3) || (prevRow == 3 && nextRow == 1))
    }

    func findBestFuzzySyllable(_ input: String, isEnabled: Bool) -> (syllable: String, consumedLength: Int)? {
        guard isEnabled, !input.isEmpty else { return nil }
        
        // Fast path: Check the sliding match cache first
        if let cachedResult = SlidingMatchCache.shared.get(input) {
            if let result = cachedResult {
                return (result.syllable, input.count)
            }
        }
        
        let chars = Array(input.lowercased())
        var potentialBoundaries = Set<Int>()
        
        var i = 1
        var foundSeparator = false
        while i < chars.count {
            let char = chars[i]
            
            if char == "|" {
                potentialBoundaries.insert(i)
                foundSeparator = true
                break
            }
            
            if potentialBoundaries.count < 5 {
                if strongInitials.contains(char) {
                    let prevChar = chars[i-1]
                    let isCompoundH = char == "h" && (prevChar == "s" || prevChar == "z" || prevChar == "c")
                    
                    if !isCompoundH && !isMiddleRowPassThrough(chars, at: i) {
                        potentialBoundaries.insert(i)
                    }
                }
                
                if char == "n" {
                    if i + 1 < chars.count && chars[i+1] == "g" {
                    } else {
                        potentialBoundaries.insert(i + 1)
                    }
                } else if char == "g" {
                    potentialBoundaries.insert(min(i + 1, chars.count))
                }
            }
            
            i += 1
        }
        
        if !foundSeparator {
            potentialBoundaries.insert(chars.count)
        }
        
        let sortedBoundaries = potentialBoundaries.sorted()
        var bestResult: (syllable: String, boundary: Int, score: Double)? = nil
        
        for boundary in sortedBoundaries {
            let noisyPart = String(chars[0..<boundary])
            
            // Internal fragment cache check
            if let cached = SlidingMatchCache.shared.get(noisyPart) {
                if let val = cached, val.score > (bestResult?.score ?? -1) {
                    bestResult = (val.syllable, boundary, val.score)
                }
                continue
            }
            
            guard let firstChar = noisyPart.first,
                  let candidates = PinyinFrequencyTable.grouped[firstChar] else {
                SlidingMatchCache.shared.set(noisyPart, result: nil)
                continue
            }
            
            let noisySet = Set(noisyPart)
            var bestForThisNoisy: (syllable: String, score: Double)? = nil
            
            for (syllable, freq) in candidates {
                if abs(syllable.count - noisyPart.count) > 3 { continue }
                
                let candidateSet = Set(syllable)
                let intersectionCount = noisySet.intersection(candidateSet).count
                
                let similarity = Double(intersectionCount) / Double(syllable.count)
                let noisePenalty = Double(syllable.count) / Double(noisyPart.count)
                
                if similarity >= 0.8 {
                    let score = similarity * noisePenalty * log10(Double(freq))
                    if score > (bestForThisNoisy?.score ?? -1) {
                        bestForThisNoisy = (syllable, score)
                    }
                }
            }
            
            SlidingMatchCache.shared.set(noisyPart, result: bestForThisNoisy)
            
            if let val = bestForThisNoisy, val.score > (bestResult?.score ?? -1) {
                bestResult = (val.syllable, boundary, val.score)
            }
        }
        
        if let res = bestResult {
            print("[SlidingFuzzy] Input: '\(input.prefix(res.boundary))' -> Match: '\(res.syllable)' (Score: \(String(format: "%.2f", res.score)))")
            return (res.syllable, res.boundary)
        }
        
        return nil
    }
}
