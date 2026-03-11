import Foundation

class PinyinTrieNode {
    var children: [Character: PinyinTrieNode] = [:]
    var isWord: Bool = false
}

struct PinyinSegment {
    let text: String
    let isValid: Bool
    let startIndex: Int
    let endIndex: Int
    let sequenceNumber: Int
}

struct PinyinSegmentationResult {
    let segments: [PinyinSegment]
    let exactPinyin: PinyinPath
    let prefixPinyinWithAbbr: PinyinPath
    let abbrWithSuffixPinyin: PinyinPath
    let pureAbbr: PinyinPath
    let isFullySegmented: Bool
}

struct PinyinPath {
    let pathType: PinyinPathType
    let pinyin: String
    let pinyinPrefix: String
    let pinyinSuffix: String
    let abbr: String
    let displayText: String
    let rawLength: Int
    let isValid: Bool
}

enum PinyinPathType {
    case exactPinyin
    case prefixPinyinWithAbbr
    case abbrWithSuffixPinyin
    case pureAbbr
}

struct QueryStrategyResult {
    let candidates: [Candidate]
    let translations: [[String]]?
}