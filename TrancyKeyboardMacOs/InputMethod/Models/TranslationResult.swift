import Foundation

struct TranslationResult: Codable, Equatable {
        let originalText: String
        let translatedText: String
        init(
        originalText: String,
        translatedText: String,
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
    }
}


