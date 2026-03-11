import Foundation

class TranslationIntegrationService {
    private var translationViewModel: TranslationServiceViewModel?
    private var systemTranslationCache: [String: [String]] = [:]
    private var currentRequestID: UUID?
    
    var onTranslationResultUpdate: ((TranslationResult) -> Void)?
    var onCandidatesWithTranslationsUpdate: (([Candidate], [[String]]) -> Void)?
    
    private func detectLanguagePair(for text: String) -> (source: String, target: String) {
        let hasChinese = text.range(of: "\\p{Han}", options: .regularExpression) != nil
        if hasChinese {
            return (source: "zh-Hans", target: "en")
        } else {
            return (source: "en", target: "zh-Hans")
        }
    }
    
    private static var _translationCandidates: [String: TranslationResult] = [:]
    var translationCandidates: [String: TranslationResult] {
        get { TranslationIntegrationService._translationCandidates }
        set { TranslationIntegrationService._translationCandidates = newValue }
    }
    
    func setTranslationService(_ viewModel: TranslationServiceViewModel) {
        self.translationViewModel = viewModel
    }
    
    func setupTranslationService() {
        // Initialization if needed
    }
    
    func clearTranslationState() {
        translationCandidates.removeAll()
        currentRequestID = UUID()
    }
    
    func getCachedTranslations(for candidates: [Candidate]) -> [[String]] {
        return candidates.map { systemTranslationCache[$0.text] ?? [] }
    }
    
    func requestMissingTranslations(for candidates: [Candidate]) {
        currentRequestID = UUID()
        let topCount = min(candidates.count, 5)
        var missingTexts: [String] = []
        for i in 0..<topCount {
            let candidate = candidates[i]
            if candidate.text.count > 1 && candidate.pinyin != "emoji" && candidate.pinyin != "symbols" && systemTranslationCache[candidate.text] == nil {
                missingTexts.append(candidate.text)
            }
        }
        if !missingTexts.isEmpty {
            requestTranslations(for: missingTexts, candidates: candidates)
        }
    }
    
    func handleCandidatesWithTranslations(_ candidates: [Candidate], inputMode: InputMode) {
        guard inputMode == .chinesePreview else {
            return
        }
        
        currentRequestID = UUID()
        updateCandidatesUI(candidates)
        
        let topCount = min(candidates.count, 5)
        var missingIndices: [Int] = []
        
        for i in 0..<topCount {
            let candidate = candidates[i]
            let text = candidate.text
            
            if text.count <= 1 || candidate.pinyin == "emoji" || candidate.pinyin == "symbols" {
                continue
            }
            
            if systemTranslationCache[text] == nil {
                missingIndices.append(i)
            }
        }
        
        if !missingIndices.isEmpty {
            let missingTexts = missingIndices.map { candidates[$0].text }
            requestTranslations(for: missingTexts, candidates: candidates)
        }
    }
    
    func updateCandidatesUI(_ candidates: [Candidate]) {
        var displayTranslations: [[String]] = []
        
        for candidate in candidates {
            var trans: [String] = []
            if let cached = systemTranslationCache[candidate.text] {
                trans = cached
            }
            displayTranslations.append(trans)
        }
        
        onCandidatesWithTranslationsUpdate?(candidates, displayTranslations)
    }
    
    func cacheTranslations(_ candidates: [Candidate], _ translations: [[String]]?) {
        guard let translations = translations else { return }
        for (index, candidate) in candidates.enumerated() {
            if index < translations.count {
                let trans = translations[index]
                if !trans.isEmpty {
                    let uniqueTrans = Array(NSOrderedSet(array: trans)).map { $0 as! String }
                    
                    if systemTranslationCache[candidate.text] == nil {
                        systemTranslationCache[candidate.text] = uniqueTrans
                    } else {
                        var existing = systemTranslationCache[candidate.text] ?? []
                        for t in uniqueTrans {
                            if !existing.contains(t) {
                                existing.append(t)
                            }
                        }
                        systemTranslationCache[candidate.text] = existing
                    }
                }
            }
        }
    }
    
    func requestTranslations(for texts: [String], candidates: [Candidate]) {
        guard let viewModel = translationViewModel, let firstText = texts.first else { return }
        
        let requestID = self.currentRequestID
        let langPair = detectLanguagePair(for: firstText)
        
        viewModel.requestBatchTranslation(texts: texts, from: langPair.source, to: langPair.target) { [weak self] results in
            guard let self = self else { return }
            guard self.currentRequestID == requestID else {
                print("⚠️ [TranslationService] 忽略过期的翻译回调")
                return
            }
            
            var hasUpdates = false
            for (original, translated) in results {
                guard original != translated else { continue }
                let existing = self.systemTranslationCache[original] ?? []
                if !existing.contains(translated) {
                    var newTranslations = existing
                    newTranslations.append(translated)
                    self.systemTranslationCache[original] = newTranslations
                    hasUpdates = true
                }
            }
            
            if hasUpdates {
                self.updateCandidatesUI(candidates)
            }
        }
    }
    
    func requestTranslation(text: String) {
        guard let viewModel = translationViewModel else { return }
        let langPair = detectLanguagePair(for: text)
        
        viewModel.requestTranslation(text: text, from: langPair.source, to: langPair.target) { [weak self] originalText, translatedText in
            guard let self = self else { return }
            guard originalText != translatedText else { return }
            let result = TranslationResult(
                originalText: originalText,
                translatedText: translatedText
            )
            self.onTranslationResultUpdate?(result)
        }
    }
    
    func requestTranslationForLearning(chineseWord: String, repository: PinyinRepository) {
        guard let viewModel = translationViewModel else {
            return
        }
        
        let langPair = detectLanguagePair(for: chineseWord)
        viewModel.requestTranslation(text: chineseWord, from: langPair.source, to: langPair.target) { [weak self] originalText, translatedText in
            guard self != nil else { return }
            guard originalText == chineseWord else { return }
            
            _ = repository.insertLearningRecordWithWords(chineseWord: originalText, englishWord: translatedText)
        }
    }
}
