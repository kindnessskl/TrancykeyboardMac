
import Foundation

struct DoublePinyinFlypy {
    static let shared = DoublePinyinFlypy()
    
    private init() {}
    
    private let initialMapping: [String: String] = [
        "q": "q", "w": "w", "e": "e", "r": "r", "t": "t", "y": "y",
        "u": "sh", "i": "ch", "o": "o", "p": "p", "a": "a", "s": "s",
        "d": "d", "f": "f", "g": "g", "h": "h", "j": "j", "k": "k",
        "l": "l", "z": "z", "x": "x", "c": "c", "v": "zh", "b": "b",
        "n": "n", "m": "m"
    ]
    
    private let finalMapping: [String: [String: String]] = [
        "*": [
            "a": "a", "o": "o", "e": "e", "i": "i", "u": "u", "v": "v",
            "b": "in", "c": "ao", "d": "ai", "f": "en", "g": "eng", "h": "ang",
            "j": "an", "k": "ing", "l": "uang", "m": "ian", "n": "iao", "p": "ie",
            "q": "iu", "r": "uan", "s": "ong", "t": "ue", "w": "ei", "y": "un", "z": "ou",
            "x": "ia"
        ],
        "g": ["k": "uai", "x": "ua", "v": "ui", "o": "uo"],
        "k": ["k": "uai", "x": "ua", "v": "ui", "o": "uo"],
        "h": ["k": "uai", "x": "ua", "v": "ui", "o": "uo"],
        "zh": ["k": "uai", "x": "ua", "v": "ui", "o": "uo"],
        "ch": ["k": "uai", "x": "ua", "v": "ui", "o": "uo"],
        "sh": ["k": "uai", "x": "ua", "v": "ui", "o": "uo"],
        "r": ["o": "uo", "v": "ui", "x": "ua", "k": "uai"],
        "z": ["o": "uo", "v": "ui", "x": "ua", "k": "uai"],
        "c": ["o": "uo", "v": "ui", "x": "ua", "k": "uai"],
        "s": ["o": "uo", "v": "ui", "x": "ua", "k": "uai"],
        "d": ["o": "uo", "v": "ui", "x": "ua", "k": "uai"],
        "t": ["o": "uo", "v": "ui", "x": "ua", "k": "uai"],
        "j": ["s": "iong", "t": "ve", "v": "v", "x": "ia"],
        "q": ["s": "iong", "t": "ve", "v": "v", "x": "ia"],
        "x": ["s": "iong", "t": "ve", "v": "v", "x": "ia"],
        "n": ["t": "ve", "l": "iang"],
        "l": ["t": "ve", "l": "iang"],
        "b": ["l": "iang"],
        "p": ["l": "iang"],
        "m": ["l": "iang"],
        "f": ["l": "iang"]
    ]
    
    private let zeroInitialMapping: [String: String] = [
        "aa": "a", "ai": "ai", "an": "an", "ah": "ang", "ao": "ao",
        "ee": "e", "ei": "ei", "en": "en", "eg": "eng", "er": "er",
        "oo": "o", "ou": "ou"
    ]

    func convertToFullPinyin(_ doublePinyin: String) -> String {
        guard !doublePinyin.isEmpty else { return doublePinyin }
        
        var result: [String] = []
        var currentPos = 0
        let chars = Array(doublePinyin.lowercased())
        
        while currentPos < chars.count {
            let remaining = chars.count - currentPos
            
            if remaining >= 2 {
                let syllable = String(chars[currentPos..<currentPos+2])
                if let converted = convertDoublePinyinSyllable(syllable) {
                    result.append(converted)
                    currentPos += 2
                    continue
                }
            }
            
            let singleChar = String(chars[currentPos])
            if let converted = convertDoublePinyinSyllable(singleChar) {
                result.append(converted)
            } else {
                result.append(singleChar)
            }
            currentPos += 1
        }
        
        return result.joined()
    }
    
    private func convertDoublePinyinSyllable(_ syllable: String) -> String? {
        let chars = Array(syllable)
        
        if syllable.count == 1 {
            let char = String(chars[0])
            return zeroInitialMapping[char] ?? initialMapping[char] ?? char
        }
        
        let firstKey = String(chars[0])
        let secondKey = String(chars[1])
        
        if let zeroInitial = zeroInitialMapping[syllable] {
            return zeroInitial
        }
        
        let mappedInitial = initialMapping[firstKey] ?? firstKey
        
        var mappedFinal: String?
        
        if let specificMapping = finalMapping[mappedInitial]?[secondKey] {
            mappedFinal = specificMapping
        }
        else if let universalMapping = finalMapping["*"]?[secondKey] {
            mappedFinal = universalMapping
        }
        
        guard let final = mappedFinal else { return nil }
        
        if ["j", "q", "x"].contains(mappedInitial) && final == "v" {
            return mappedInitial + "u"
        }
        if ["j", "q", "x"].contains(mappedInitial) && final.hasPrefix("v") {
             let correctedFinal = final.replacingOccurrences(of: "v", with: "u")
             return mappedInitial + correctedFinal
        }
        
        if ["n", "l"].contains(mappedInitial) && final == "v" {
            return mappedInitial + "ü"
        }
        
        return mappedInitial + final
    }

    func isValidDoublePinyin(_ input: String) -> Bool {
        let converted = convertToFullPinyin(input)
        return converted != input
    }
}
