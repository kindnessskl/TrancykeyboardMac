import Foundation

class PinyinValidator {
    static let shared = PinyinValidator()

    private var validSyllables: Set<String> = []
    private var isLoaded = false

    private init() {
        loadValidSyllables()
    }

    private func loadValidSyllables() {
        guard !isLoaded else { return }

        let bundles = [
            Bundle.main,
            Bundle(for: type(of: self))
        ]

        for bundle in bundles {
            if let path = bundle.path(forResource: "valid_pinyin_syllables", ofType: "json"),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let json = try? JSONDecoder().decode(PinyinSyllablesData.self, from: data) {
                validSyllables = Set(json.syllables)
                isLoaded = true
                return
            }
        }
    }

    func isValid(_ syllable: String) -> Bool {
        return validSyllables.contains(syllable.lowercased())
    }

    func isValid(_ syllable: String, requiredLength: Int) -> Bool {
        let lower = syllable.lowercased()
        return validSyllables.contains(lower) && lower.count == requiredLength
    }

    func isValidSequence(_ syllables: [String]) -> Bool {
        return syllables.allSatisfy { isValid($0) }
    }

    func filterValid(from syllables: [String]) -> [String] {
        return syllables.filter { isValid($0) }
    }

    func getTotalCount() -> Int {
        return validSyllables.count
    }

    func getAllSyllables() -> [String] {
        return Array(validSyllables).sorted()
    }

    func isSpecialInitial(_ syllable: String) -> Bool {
        return syllable.hasPrefix("zh") || syllable.hasPrefix("ch") || syllable.hasPrefix("sh")
    }

    func getInitial(from syllable: String) -> String {
        if isSpecialInitial(syllable) {
            return String(syllable.prefix(2))
        }
        return String(syllable.prefix(1))
    }
}

private struct PinyinSyllablesData: Codable {
    let syllables: [String]
}

