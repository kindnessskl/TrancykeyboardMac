import Foundation

class UserBehaviorService {
    private let repository = PinyinRepository.shared
    private let backgroundQueue = DispatchQueue(label: "com.trancy.keyboard.userBehavior", qos: .utility)
    
    var isSelectionFrequencyEnabled: Bool = false
    var isSelectionRecordEnabled: Bool = false
    
    private var sessionCandidates: [(candidate: Candidate, inputMode: InputMode, translationService: TranslationIntegrationService)] = []
    
    func recordUserSelection(_ candidate: Candidate, inputMode: InputMode, translationService: TranslationIntegrationService) {
        sessionCandidates.append((candidate, inputMode, translationService))
    }
    
    func commitSession() {
        guard !sessionCandidates.isEmpty,
              let firstItem = sessionCandidates.first else {
            clearSession()
            return
        }
        
        let combinedText = sessionCandidates.map { $0.candidate.text }.joined()
        let combinedPinyin = sessionCandidates.map { $0.candidate.pinyin }.joined(separator: " ")
        
        // Capture data for background task
        let inputMode = firstItem.inputMode
        let translationService = firstItem.translationService
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            print("提交检查Text: \(combinedText), Pinyin: \(combinedPinyin)")
            self.performRecordUserSelection(
                text: combinedText,
                pinyin: combinedPinyin,
                inputMode: inputMode,
                translationService: translationService,
                isSelectionFrequencyEnabled: self.isSelectionFrequencyEnabled,
                isSelectionRecordEnabled: self.isSelectionRecordEnabled
            )
        }
        
        clearSession()
    }
    
    func clearSession() {
        sessionCandidates.removeAll()
    }
    
    private func performRecordUserSelection(
        text: String,
        pinyin: String,
        inputMode: InputMode,
        translationService: TranslationIntegrationService,
        isSelectionFrequencyEnabled: Bool,
        isSelectionRecordEnabled: Bool
    ) {
        
        guard isChinese(text) else {
            print("Skip non-Chinese record: \(text)")
            return
        }
        
        let chineseWord = text
        let chineseId: Int
        
        if let existingChineseId = repository.getChineseWordId(chineseWord) {
            print("已存在: \(existingChineseId) ")
            chineseId = existingChineseId
        } else { 
            chineseId = repository.insertChineseWord(chineseWord, pinyin: pinyin)
            print("新插入: \(chineseId) ")
        }
        
        if chineseId > 0 {
            if isSelectionFrequencyEnabled {
                _ = repository.updateChineseWordFrequency(chineseId: chineseId, pinyin: pinyin)
            }
            
            if isSelectionRecordEnabled {
                if let englishId = repository.findEnglishIdForChinese(chineseId) {
                    _ = repository.insertLearningRecord(chineseId: chineseId, englishId: englishId)
                } else {
                    translationService.requestTranslationForLearning(chineseWord: chineseWord, repository: repository)
                }
            }
        }
    }
    
    private func isChinese(_ text: String) -> Bool {
        if text.isEmpty { return false }
        let pattern = "^[\\u{4E00}-\\u{9FFF}]+$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    private func isEnglish(_ text: String) -> Bool {
        if text.isEmpty { return false }
        let pattern = "^[A-Za-z]+$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    
    func selectEnglishTranslation(_ text: String, for candidate: Candidate, translationService: TranslationIntegrationService) {
        let trimmedEnglish = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChinese = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isChinese(trimmedChinese), isEnglish(trimmedEnglish) else {
                print("跳过翻译记录: 中文(\(trimmedChinese)), 英文(\(trimmedEnglish))")
                return
            }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            if let englishId = self.repository.getEnglishWordId(trimmedEnglish) {
                if self.isSelectionFrequencyEnabled {
                    _ = self.repository.updateEnglishWordFrequency(englishId: englishId)
                }
                
                if self.isSelectionRecordEnabled {
                    if let chineseId = self.repository.getChineseWordId(trimmedChinese) {
                        _ = self.repository.insertLearningRecord(chineseId: chineseId, englishId: englishId)
                        print("更新英语学习表: \(trimmedEnglish)")
                    }
                }
            } else {
                if self.isSelectionRecordEnabled {
                    _ = self.repository.insertLearningRecordWithWords(chineseWord: trimmedChinese, englishWord: trimmedEnglish)
                    print("插入英语学习表: \(trimmedEnglish)")
                }
            }
        }
        
        translationService.clearTranslationState()
    }
}
