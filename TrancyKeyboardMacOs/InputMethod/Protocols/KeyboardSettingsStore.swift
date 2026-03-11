import SwiftUI
import Combine

class KeyboardSettingsStore: ObservableObject {
    @Published var isAutoCorrectEnabled: Bool
    @Published var isKeyboardCorrectEnabled: Bool
    @Published var isDoublePinyinEnabled: Bool
    @Published var isAutoSuggestionEnabled: Bool
    @Published var isSelectionRecordEnabled: Bool
    @Published var isSelectionFrequencyEnabled: Bool
    @Published var isEnglishLookupEnabled: Bool
    @Published var isEnglishFuzzyLookupEnabled: Bool
    @Published var isEnglishPrefixLookupEnabled: Bool
    @Published var isChineseLookupEnabled: Bool
    @Published var isEmojiEnabled: Bool
    @Published var isSymbolsEnabled: Bool
    @Published var isSlidingFuzzyEnabled: Bool
    @Published var isAutoSplitEnabled: Bool
    
    @Published var dualCandidateOutputMode: DualCandidateOutputMode
    @Published var candidateFontSize: CandidateFontSize
    @Published var appLanguage: AppLanguage
    @Published var chineseOutputMode: ChineseOutputMode
    @Published var currentMode: InputMode
    
    // 同步相关
    @Published var isCloudSyncEnabled: Bool
    @Published var isSyncing: Bool = false
    @Published var lastSyncTimestamp: Int

    private var cancellables = Set<AnyCancellable>()
    private let storage = SharedUserDefaults.shared
    
    init(currentMode: InputMode) {
        self.isAutoCorrectEnabled = storage.bool(forKey: "isAutoCorrectEnabled")
        self.isKeyboardCorrectEnabled = storage.bool(forKey: "isKeyboardCorrectEnabled")
        self.isDoublePinyinEnabled = storage.bool(forKey: "isDoublePinyinEnabled")
        self.isAutoSuggestionEnabled = storage.bool(forKey: "isAutoSuggestionEnabled")
        self.isSelectionRecordEnabled = storage.bool(forKey: "isSelectionRecordEnabled")
        self.isSelectionFrequencyEnabled = storage.bool(forKey: "isSelectionFrequencyEnabled")
        self.isEnglishLookupEnabled = storage.bool(forKey: "isEnglishLookupEnabled")
        self.isEnglishFuzzyLookupEnabled = storage.bool(forKey: "isEnglishFuzzyLookupEnabled")
        self.isEnglishPrefixLookupEnabled = storage.bool(forKey: "isEnglishPrefixLookupEnabled", defaultValue: true)
        self.isChineseLookupEnabled = storage.bool(forKey: "isChineseLookupEnabled", defaultValue: true)
        self.isEmojiEnabled = storage.bool(forKey: "isEmojiEnabled")
        self.isSymbolsEnabled = storage.bool(forKey: "isSymbolsEnabled")
        self.isSlidingFuzzyEnabled = storage.bool(forKey: "isSlidingFuzzyEnabled", defaultValue: true)
        self.isAutoSplitEnabled = storage.bool(forKey: "isAutoSplitEnabled", defaultValue: true)
        
        self.isCloudSyncEnabled = storage.bool(forKey: "isCloudSyncEnabled")
        self.lastSyncTimestamp = storage.integer(forKey: "com.trancy.sync.lastSyncTimestamp")
        
        let savedDualMode = storage.integer(forKey: dualCandidateOutputModeKey)
        self.dualCandidateOutputMode = DualCandidateOutputMode(rawValue: savedDualMode) ?? .default
        
        let savedSize = storage.integer(forKey: candidateFontSizeKey)
        self.candidateFontSize = CandidateFontSize(rawValue: savedSize) ?? .medium
                
        let savedLang = storage.string(forKey: "appLanguage") ?? "zh-Hans"
        self.appLanguage = AppLanguage(rawValue: savedLang) ?? .simplifiedChinese
        
        let savedOutputMode = storage.integer(forKey: "chineseOutputMode")
        self.chineseOutputMode = ChineseOutputMode(rawValue: savedOutputMode) ?? .simplified
        
        // 初始模式逻辑
        if let savedModeStr = storage.string(forKey: "selectedInputMode"),
           let mode = InputMode(rawValue: savedModeStr) {
            self.currentMode = mode
        } else {
            self.currentMode = currentMode
        }
        
        setupObservers()
    }
    
    private func setupObservers() {
        $isAutoCorrectEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isAutoCorrectEnabled"); self?.post() }.store(in: &cancellables)
        $isKeyboardCorrectEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isKeyboardCorrectEnabled"); self?.post() }.store(in: &cancellables)
        $isDoublePinyinEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isDoublePinyinEnabled"); self?.post() }.store(in: &cancellables)
        $isAutoSuggestionEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isAutoSuggestionEnabled"); self?.post() }.store(in: &cancellables)
        $isSelectionRecordEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isSelectionRecordEnabled"); self?.post() }.store(in: &cancellables)
        $isSelectionFrequencyEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isSelectionFrequencyEnabled"); self?.post() }.store(in: &cancellables)
        $isEnglishLookupEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isEnglishLookupEnabled"); self?.post() }.store(in: &cancellables)
        $isEnglishFuzzyLookupEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isEnglishFuzzyLookupEnabled"); self?.post() }.store(in: &cancellables)
        $isEnglishPrefixLookupEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isEnglishPrefixLookupEnabled"); self?.post() }.store(in: &cancellables)
        $isChineseLookupEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isChineseLookupEnabled"); self?.post() }.store(in: &cancellables)
        $isEmojiEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isEmojiEnabled"); self?.post() }.store(in: &cancellables)
        $isSymbolsEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isSymbolsEnabled"); self?.post() }.store(in: &cancellables)
        $isSlidingFuzzyEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isSlidingFuzzyEnabled"); self?.post() }.store(in: &cancellables)
        $isAutoSplitEnabled.sink { [weak self] in self?.storage.set($0, forKey: "isAutoSplitEnabled"); self?.post() }.store(in: &cancellables)
        
        $dualCandidateOutputMode.sink { [weak self] in self?.storage.set($0.rawValue, forKey: dualCandidateOutputModeKey); self?.post() }.store(in: &cancellables)
        $candidateFontSize.sink { [weak self] in self?.storage.set($0.rawValue, forKey: candidateFontSizeKey); self?.post() }.store(in: &cancellables)
        $appLanguage.sink { [weak self] in self?.storage.set($0.rawValue, forKey: "appLanguage"); self?.post() }.store(in: &cancellables)
        $chineseOutputMode.sink { [weak self] in self?.storage.set($0.rawValue, forKey: "chineseOutputMode"); self?.post() }.store(in: &cancellables)
        
        $currentMode.sink { [weak self] in self?.storage.set($0.rawValue, forKey: "selectedInputMode"); self?.post() }.store(in: &cancellables)
        
        $isCloudSyncEnabled.sink { [weak self] in 
            self?.storage.set($0, forKey: "isCloudSyncEnabled")
            if $0 { self?.triggerSync() }
            self?.post() 
        }.store(in: &cancellables)
    }
    
    func triggerSync() {
        guard !isSyncing else { return }
        isSyncing = true
        iCloudSyncManager.shared.performSync(force: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSyncing = false
                self?.lastSyncTimestamp = self?.storage.integer(forKey: "com.trancy.sync.lastSyncTimestamp") ?? 0
            }
        }
    }
    
    private func post() {
        NotificationCenter.default.post(name: .keyboardSettingsDidChange, object: nil)
    }
}

extension Notification.Name {
    static let doublePinyinModeChanged = Notification.Name("doublePinyinModeChanged")
    static let keyboardSettingsDidChange = Notification.Name("keyboardSettingsDidChange")
}
