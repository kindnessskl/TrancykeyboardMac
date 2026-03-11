import Foundation

class CandidatePresentationService {
    var sessionCachedCandidates: [Candidate] = []
    private var lastValidCandidates: [Candidate] = []
    
    private let translationService: TranslationIntegrationService
    
    var onCandidatesUpdate: (([Candidate]) -> Void)?
    
    init(translationService: TranslationIntegrationService) {
        self.translationService = translationService
    }
    
    func clearCache() {
        sessionCachedCandidates = []
        lastValidCandidates = []
    }
    
    func addToSessionCache(_ candidates: [Candidate], _ translations: [[String]]? = nil) {
        let newTexts = Set(candidates.map { $0.text })
        sessionCachedCandidates.removeAll { newTexts.contains($0.text) }
        sessionCachedCandidates.insert(contentsOf: candidates, at: 0)
        
        translationService.cacheTranslations(candidates, translations)
    }
    
    func updateCandidatesWithFallback(_ candidates: [Candidate], _ translations: [[String]]? = nil, inputMode: InputMode) -> [Candidate] {
        var finalCandidates: [Candidate] = []
        var seenTexts = Set<String>()
        
        for candidate in candidates {
            if !seenTexts.contains(candidate.text) {
                seenTexts.insert(candidate.text)
                finalCandidates.append(candidate)
            }
        }
        
        for cached in sessionCachedCandidates {
            if !seenTexts.contains(cached.text) {
                seenTexts.insert(cached.text)
                finalCandidates.append(cached)
            }
        }
        
        if !finalCandidates.isEmpty {
            lastValidCandidates = finalCandidates
        } else {
            finalCandidates = lastValidCandidates
        }
        
        let displayedCandidates = Array(finalCandidates.prefix(300))
        
        if inputMode == .chinesePreview {
            translationService.cacheTranslations(candidates, translations)
        }
        
        return displayedCandidates
    }
}
 
