import Foundation
import AppKit

enum ActiveLayer {
    case chinese
    case english
}

class KeyViewModel {
    private let queryService: InputQueryService
    private let translationService: TranslationIntegrationService
    private let presentationService: CandidatePresentationService
    private let userBehaviorService: UserBehaviorService
    private var translationViewModel: TranslationServiceViewModel?
    
    private(set) var inputMode: InputMode = .chinesePreview
    
    private var cachedFontSize: CandidateFontSize = .medium
    private var cachedSpacing: CandidateSpacing = .normal
    
    var activeLayer: ActiveLayer = .chinese
    var highlightedIndex: Int = 0 
    var currentPage: Int = 0
    var pageSize: Int = 9
    private(set) var pageBreakpoints: [Int] = [0]
    private(set) var candidateWidths: [Int] = []
    var isExpanded: Bool = false
    private var isWaitingForSelectionTranslation: Bool = false
    
    var isInSelectionTranslationMode: Bool {
        return isWaitingForSelectionTranslation || (currentInput.isEmpty && !displayedCandidates.isEmpty && displayedCandidates.first?.pinyin == "translated")
    }
    
    var currentInput: String = ""
    var displayedCandidates: [Candidate] = []
    private var currentPaths: [PinyinPath] = []

    private var chineseLayoutFont = NSFont.systemFont(ofSize: 20)
    private var englishLayoutFont = NSFont.systemFont(ofSize: 16)
    private var widthCache: [String: CGFloat] = [:]
    
    private let queryQueue = DispatchQueue(label: "com.trancy.keyboard.query", qos: .userInitiated)
    
    var onMarkedTextUpdate: ((String) -> Void)?
    var onCandidatesUpdate: (([Candidate]) -> Void)?
    var onCandidatesWithTranslationsUpdate: (([Candidate], [[String]]) -> Void)?
    var onTextOutput: ((String) -> Void)?
    var onClearMarkedText: (() -> Void)?
    var onTranslationResultUpdate: ((TranslationResult) -> Void)?
    var onDatabaseError: (() -> Void)?
    
    init() {
        self.queryService = InputQueryService()
        self.translationService = TranslationIntegrationService()
        self.presentationService = CandidatePresentationService(translationService: self.translationService)
        self.userBehaviorService = UserBehaviorService()
        refreshSettings()
        self.queryService.onExactPinyinMatch = { [weak self] candidates, translations in
            self?.presentationService.addToSessionCache(candidates, translations)
        }
        setupBindings()
        observeLayoutChange()
        checkDatabaseStatus()
    }
    
    private func checkDatabaseStatus() {
        if !PinyinRepository.shared.isReady {
            DispatchQueue.main.async {
                self.onDatabaseError?()
            }
        }
    }
    
    private func setupBindings() {
        presentationService.onCandidatesUpdate = { [weak self] candidates in
            self?.displayedCandidates = candidates
            self?.notifyUIRefresh()
        }
        translationService.onCandidatesWithTranslationsUpdate = { [weak self] candidates, translations in
            self?.displayedCandidates = candidates
            self?.notifyUIRefresh()
        }
        translationService.onTranslationResultUpdate = { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let isWaiting = self.isWaitingForSelectionTranslation ||
                               (self.displayedCandidates.first?.pinyin == "waiting")
                
                if isWaiting && self.currentInput.isEmpty {
                    self.isWaitingForSelectionTranslation = false
                    let translatedCandidate = Candidate(text: result.translatedText, pinyin: "translated", frequency: 1000, strokeCount: 0)
                    self.displayedCandidates = [translatedCandidate]
                    self.notifyUIRefresh()
                }
                self.onTranslationResultUpdate?(result)
            }
        }
    }
    
    private func observeLayoutChange() {
        NotificationCenter.default.addObserver(forName: .keyboardSettingsDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.refreshSettings()
        }
        NotificationCenter.default.addObserver(forName: .doublePinyinModeChanged, object: nil, queue: .main) { [weak self] notification in
            guard let enabled = notification.object as? Bool else { return }
            self?.setDoublePinyinMode(enabled)
        }
    }
    
    private func refreshSettings() {
        let defaults = SharedUserDefaults.shared
        queryService.isDoublePinyinEnabled = defaults.bool(forKey: "isDoublePinyinEnabled", defaultValue: false)
        queryService.isEmojiEnabled = defaults.bool(forKey: "isEmojiEnabled", defaultValue: true)
        queryService.isSymbolsEnabled = defaults.bool(forKey: "isSymbolsEnabled", defaultValue: true)
        queryService.isAutoSplitEnabled = defaults.bool(forKey: "isAutoSplitEnabled", defaultValue: true)
        queryService.isEnglishLookupEnabled = defaults.bool(forKey: "isEnglishLookupEnabled", defaultValue: true)
        queryService.isEnglishPrefixLookupEnabled = defaults.bool(forKey: "isEnglishPrefixLookupEnabled", defaultValue: true)
        queryService.isChineseLookupEnabled = defaults.bool(forKey: "isChineseLookupEnabled", defaultValue: true)
        queryService.isEnglishFuzzyLookupEnabled = defaults.bool(forKey: "isEnglishFuzzyLookupEnabled", defaultValue: true)
        userBehaviorService.isSelectionFrequencyEnabled = defaults.bool(forKey: "isSelectionFrequencyEnabled", defaultValue: true)
        userBehaviorService.isSelectionRecordEnabled = defaults.bool(forKey: "isSelectionRecordEnabled", defaultValue: true)
        PinyinSegmentValidator.shared.isSlidingFuzzyEnabled = defaults.bool(forKey: "isSlidingFuzzyEnabled", defaultValue: true)
        PinyinSegmentValidator.shared.isAutoCorrectEnabled = defaults.bool(forKey: "isAutoCorrectEnabled", defaultValue: true)
        PinyinSegmentValidator.shared.isKeyboardCorrectEnabled = defaults.bool(forKey: "isKeyboardCorrectEnabled", defaultValue: true)
        
        PinyinCorrectionEngine.shared.refreshSettings()
        let savedSize = defaults.integer(forKey: candidateFontSizeKey, defaultValue: 1)
        self.cachedFontSize = CandidateFontSize(rawValue: savedSize) ?? .medium
        
        self.chineseLayoutFont = NSFont.systemFont(ofSize: self.cachedFontSize.chineseSize)
        self.englishLayoutFont = NSFont.systemFont(ofSize: self.cachedFontSize.englishSize)
        
        let savedSpacing = defaults.integer(forKey: candidateSpacingKey, defaultValue: 1)
        self.cachedSpacing = CandidateSpacing(rawValue: savedSpacing) ?? .normal
        let savedDualMode = defaults.integer(forKey: dualCandidateOutputModeKey, defaultValue: 0)
        let mode = DualCandidateOutputMode(rawValue: savedDualMode) ?? .default
        switch mode {
        case .chineseOnly: activeLayer = .chinese
        case .englishOnly: activeLayer = .english
        default: activeLayer = .chinese
        }
    }
    
    func setDoublePinyinMode(_ enabled: Bool) { queryService.isDoublePinyinEnabled = enabled }
    func switchInputMode(_ mode: InputMode) { inputMode = mode }
    
    func setTranslationService(_ viewModel: TranslationServiceViewModel) {
        self.translationService.setTranslationService(viewModel)
    }
    
    func segmentInput(_ input: String) -> ([PinyinPath])
        { return queryService.segmentInput(input) }
   
    func handleInput(_ input: String) {
        if isInSelectionTranslationMode {
            isWaitingForSelectionTranslation = false
            displayedCandidates = []
            onCandidatesUpdate?([])
        }
        currentInput += input
        updateInput()
    }
    
    func handleSeparator() {
        if !currentInput.isEmpty {
            currentInput += "|"
        }
    }

    func handleSelectedTextTranslation(_ text: String) {
        clearInput()
        isWaitingForSelectionTranslation = true
        let placeholder = Candidate(text: " ", pinyin: "waiting", frequency: 0, strokeCount: 0)
        displayedCandidates = [placeholder]
        onCandidatesUpdate?(displayedCandidates)
        
        translationService.requestTranslation(text: text)
    }

    func clearInput() {
        userBehaviorService.clearSession()
        isWaitingForSelectionTranslation = false
        queryService.resetQueryState()
        currentInput = ""
        currentPaths = []
        displayedCandidates = []
        widthCache.removeAll()
        
        highlightedIndex = 0
        currentPage = 0
        pageSize = 0
        pageBreakpoints = [0]
        isExpanded = false
        
        presentationService.clearCache()
        translationService.clearTranslationState()
        onClearMarkedText?()
        onCandidatesUpdate?([])
        onCandidatesWithTranslationsUpdate?([],[])
    }
    
    func handleSpaceKey() {
        if isInSelectionTranslationMode {
            if let candidate = displayedCandidates.first, candidate.pinyin == "translated" {
                selectCandidate(candidate)
                return
            }
        }
        guard !currentInput.isEmpty else {
            onTextOutput?(" ")
            return
        }
        selectIndex(highlightedIndex)
    }
    
    func handleDeleteKey() -> Bool {
        guard !currentInput.isEmpty else { return false }
        currentInput.removeLast()
        if currentInput.isEmpty {
            clearInput()
        } else {
            updateInput()
        }
        return true
    }
    
    func selectIndex(_ index: Int, layer: ActiveLayer? = nil) {
        let start = (currentPage < pageBreakpoints.count) ? pageBreakpoints[currentPage] : 0
        let actualIndex = start + index
        guard actualIndex < displayedCandidates.count else { return }
        selectCandidate(displayedCandidates[actualIndex], layer: layer)
    }

    func selectCandidate(_ candidate: Candidate, layer: ActiveLayer? = nil) {
        let targetLayer = layer ?? activeLayer
        if targetLayer == .english {
            let translations = translationService.getCachedTranslations(for: [candidate])
            if let firstTrans = translations.first?.first {
                selectEnglishTranslation(firstTrans, for: candidate)
            } else {
                performSelectCandidate(candidate)
            }
        } else {
            performSelectCandidate(candidate)
        }
    }
    
    private func performSelectCandidate(_ candidate: Candidate) {
        userBehaviorService.recordUserSelection(candidate, inputMode: inputMode, translationService: translationService)
        let textToOutput = shouldAppendSpace(for: candidate, text: candidate.text) ? candidate.text + " " : candidate.text
        onTextOutput?(textToOutput)
        handleRemainingInput(after: candidate)
    }
    
    func selectEnglishTranslation(_ text: String, for candidate: Candidate) {
        userBehaviorService.selectEnglishTranslation(text, for: candidate, translationService: translationService)
        let textToOutput = shouldAppendSpace(for: candidate, text: text) ? text + " " : text
        onTextOutput?(textToOutput)
        clearInput()
    }

    private func isEnglish(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let hasChinese = text.range(of: "\\p{Han}", options: .regularExpression) != nil
        if hasChinese { return false }
        
        let englishLetterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return text.rangeOfCharacter(from: englishLetterSet) != nil
    }

    private func shouldAppendSpace(for candidate: Candidate, text: String) -> Bool {
        if candidate.pinyin == "emoji" || candidate.pinyin == "symbols" {
            return false
        }
        return isEnglish(text)
    }
    
    func pageDown() {
        if currentPage < pageBreakpoints.count - 1 {
            currentPage += 1
            highlightedIndex = 0
            notifyUIRefresh()
        }
    }
    
    func pageUp() {
        if currentPage > 0 {
            currentPage -= 1
            highlightedIndex = 0
            notifyUIRefresh()
        }
    }
    
    func toggleActiveLayer() {
        if inputMode == .chinesePreview {
            activeLayer = (activeLayer == .chinese) ? .english : .chinese
            notifyUIRefresh()
        }
    }
    
    func toggleExpansion(force: Bool? = nil) {
        if let force = force { isExpanded = force } else { isExpanded.toggle() }
        notifyUIRefresh()
    }
    
    func moveHighlight(direction: Direction) {
        switch direction {
        case .right:
            if highlightedIndex < pageSize - 1 { highlightedIndex += 1 } else { pageDown() }
        case .left:
            if highlightedIndex > 0 { highlightedIndex -= 1 } else { pageUp() }
        case .down: pageDown()
        case .up: pageUp()
        }
        notifyUIRefresh()
    }
    
    private func measureTextWidth(_ text: String, font: NSFont) -> CGFloat {
        let key = "\(text)_\(font.pointSize)_\(font.fontName)"
        if let cached = widthCache[key] {
            return cached
        }
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        widthCache[key] = size.width
        return size.width
    }

    func calculatePageBreakpoints() {
        guard !displayedCandidates.isEmpty else {
            pageBreakpoints = [0]
            candidateWidths = []
            pageSize = 0
            return
        }

        if isInSelectionTranslationMode {
            pageBreakpoints = [0]
            candidateWidths = [680]
            pageSize = displayedCandidates.count
            currentPage = 0
            highlightedIndex = 0
            return
        }

        var breakpoints: [Int] = [0]
        var currentIdx = 0
        var allMeasuredWidths: [Int] = []
        let maxBarWidth: CGFloat = 680.0
        let itemPadding: CGFloat = 38 

        while currentIdx < displayedCandidates.count {
            if !isExpanded && breakpoints.count > currentPage + 1 {
                break
            }

            var currentWidthSum: CGFloat = 0
            var countInPage = 0

            while currentIdx < displayedCandidates.count {
                let cand = displayedCandidates[currentIdx]
                let translation: String = {
                    if inputMode == .chinesePreview {
                        return translationService.getCachedTranslations(for: [cand]).first?.first ?? ""
                    }
                    return ""
                }()

                let candFont = isEnglish(cand.text) ? englishLayoutFont : chineseLayoutFont
                let candWidth = measureTextWidth(cand.text, font: candFont)
                
                var transWidth: CGFloat = 0
                if !translation.isEmpty {
                    let transFont = isEnglish(translation) ? englishLayoutFont : chineseLayoutFont
                    transWidth = measureTextWidth(translation, font: transFont)
                }
                
                let itemTotalWidth = max(candWidth, transWidth)

                let neededWidth = (countInPage == 0) ? itemTotalWidth : (itemPadding + itemTotalWidth)
                
                if (countInPage > 0 && currentWidthSum + neededWidth > maxBarWidth) || countInPage >= 9 {
                    break 
                }
                
                allMeasuredWidths.append(Int(itemTotalWidth))
                currentWidthSum += neededWidth
                countInPage += 1
                currentIdx += 1
            }
            if currentIdx < displayedCandidates.count {
                breakpoints.append(currentIdx)
            }
        }
        
        self.pageBreakpoints = breakpoints
        self.candidateWidths = allMeasuredWidths
        
        if currentPage >= pageBreakpoints.count {
            currentPage = max(0, pageBreakpoints.count - 1)
        }
        
        let start = pageBreakpoints[currentPage]
        let end = (currentPage + 1 < pageBreakpoints.count) ? pageBreakpoints[currentPage + 1] : min(currentIdx, displayedCandidates.count)

        self.pageSize = end - start
        if highlightedIndex >= pageSize {
            highlightedIndex = max(0, pageSize - 1)
        }
    }

    func updateInput() {
        let normalizedInput = queryService.normalizeInput(currentInput)
        let segmentationResults = queryService.segmentWithStandardMode(normalizedInput)
        let queryResult = queryService.executeSmartQuery(normalizedInput, segmentationResults: segmentationResults, inputMode: inputMode)
        let processedCandidates = self.presentationService.updateCandidatesWithFallback(queryResult.candidates, queryResult.translations, inputMode: self.inputMode)
        var currentTranslations: [[String]] = []
        if self.inputMode == .chinesePreview {
            currentTranslations = self.translationService.getCachedTranslations(for: processedCandidates)
            self.translationService.requestMissingTranslations(for: processedCandidates)
        }
        let bestSegments = segmentationResults.first?.segments ?? []
        var displayInput = PinyinSegmentValidator.shared.formatRawInput(currentInput, with: bestSegments)
        
        if let firstCandidate = processedCandidates.first,
           firstCandidate.text.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil,
           firstCandidate.text.canBeConverted(to: .ascii) {
            displayInput = currentInput
        }
        
        notifyUIUpdate(displayInput: displayInput, candidates: processedCandidates, translations: currentTranslations)
    }
    
    private func notifyUIUpdate(displayInput: String, candidates: [Candidate], translations: [[String]]) {
        self.onMarkedTextUpdate?(displayInput.lowercased())
        self.displayedCandidates = candidates
        self.calculatePageBreakpoints()
        if self.inputMode == .chinesePreview && !candidates.isEmpty {
            self.onCandidatesWithTranslationsUpdate?(candidates, translations)
        } else {
            self.onCandidatesUpdate?(candidates)
        }
    }
    
    func notifyUIRefresh() {
        calculatePageBreakpoints()
        if inputMode == .chinesePreview {
            let translations = translationService.getCachedTranslations(for: displayedCandidates)
            onCandidatesWithTranslationsUpdate?(displayedCandidates, translations)
        } else {
            onCandidatesUpdate?(displayedCandidates)
        }
    }
    
    private func handleRemainingInput(after candidate: Candidate) {
        presentationService.clearCache()
        let isSpecialType = candidate.pinyin == "emoji" || candidate.pinyin == "symbols" || candidate.type == .word && candidate.pinyin.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil && !candidate.pinyin.contains(" ")
        let cleanInput = currentInput.replacingOccurrences(of: "|", with: "")
        let consumedChars: Int
        
        if isSpecialType {
            consumedChars = cleanInput.count
        } else if candidate.matchedLength > 0 {
            consumedChars = candidate.matchedLength
        } else {
            consumedChars = candidate.pinyin.replacingOccurrences(of: " ", with: "").count
        }
        
        if consumedChars < cleanInput.count {
            var charsToConsume = consumedChars
            var index = currentInput.startIndex
            while charsToConsume > 0 && index < currentInput.endIndex {
                if currentInput[index] != "|" { charsToConsume -= 1 }
                index = currentInput.index(after: index)
            }
            let remaining = String(currentInput[index...])
            currentInput = remaining.replacingOccurrences(of: "^\\|", with: "", options: .regularExpression)
            updateInput()
        } else {
            userBehaviorService.commitSession()
            clearInput()
        }
    }
}
