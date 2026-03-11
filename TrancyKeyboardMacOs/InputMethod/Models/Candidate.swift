import Foundation

struct Candidate: Codable, Equatable, Hashable {
        let text: String
        let pinyin: String
        let frequency: Int
        let updatedAt: Int
        let type: CandidateType
        let strokeCount: Int
        var matchedLength: Int

        init(
        text: String,
        pinyin: String,
        frequency: Int,
        updatedAt: Int = 0,
        type: CandidateType = .word,
        strokeCount: Int,
        matchedLength: Int = 0
        ) {
        self.text = text
        self.pinyin = pinyin
        self.frequency = frequency
        self.updatedAt = updatedAt
        self.type = type
        self.strokeCount = strokeCount
        self.matchedLength = matchedLength
        }
}

enum CandidateType: String, Codable {
        case character
        case word
}


extension Candidate {
        var isCharacter: Bool {
        return type == .character
    }

        var isWord: Bool {
        return type == .word
    }
}

