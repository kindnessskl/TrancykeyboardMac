import SwiftUI
import Combine

struct KeyShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64
    var displayName: String

    static let mask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    static func from(event: NSEvent) -> KeyShortcut {
        let modifiers = event.modifierFlags.intersection(KeyShortcut.mask).rawValue
        let keyCode = event.keyCode
        let display = format(keyCode: keyCode, modifiers: event.modifierFlags)
        return KeyShortcut(keyCode: keyCode, modifiers: UInt64(modifiers), displayName: display)
    }

    static func format(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        let coreModifiers = modifiers.intersection(KeyShortcut.mask)
        var str = ""
        if coreModifiers.contains(.control) { str += "⌃" }
        if coreModifiers.contains(.option) { str += "⌥" }
        if coreModifiers.contains(.shift) { str += "⇧" }
        if coreModifiers.contains(.command) { str += "⌘" }

        
        let keyStr: String = {
            switch keyCode {
            case KeyCode.Special.VK_TAB: return "Tab"
            case KeyCode.Special.VK_SPACE: return "Space"
            case KeyCode.Special.VK_RETURN: return "Return"
            case KeyCode.Special.VK_ESCAPE: return "Esc"
            case KeyCode.Symbol.VK_BACKQUOTE: return "`"
            case KeyCode.Symbol.VK_SLASH: return "/"
            case KeyCode.Symbol.VK_BACKSLASH: return "\\"
            case KeyCode.Symbol.VK_SEMICOLON: return ";"
            case KeyCode.Symbol.VK_COMMA: return ","
            case KeyCode.Symbol.VK_DOT: return "."
            case KeyCode.Symbol.VK_QUOTE: return "'"
            case KeyCode.Symbol.VK_MINUS: return "-"
            case KeyCode.Symbol.VK_EQUAL: return "="
            case KeyCode.Symbol.VK_BRACKET_LEFT: return "["
            case KeyCode.Symbol.VK_BRACKET_RIGHT: return "]"
            default:
                if let char = KeyCodeToChar(keyCode) {
                    return char
                }
                return "Key(\(keyCode))"
            }
        }()
        
        return str + (str.isEmpty ? "" : " ") + keyStr.uppercased()
    }

    private static func KeyCodeToChar(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 0x0: return "A"
        case 0xb: return "B"
        case 0x8: return "C"
        case 0x2: return "D"
        case 0xe: return "E"
        case 0x3: return "F"
        case 0x5: return "G"
        case 0x4: return "H"
        case 0x22: return "I"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x25: return "L"
        case 0x2e: return "M"
        case 0x2d: return "N"
        case 0x1f: return "O"
        case 0x23: return "P"
        case 0xc: return "Q"
        case 0xf: return "R"
        case 0x1: return "S"
        case 0x11: return "T"
        case 0x20: return "U"
        case 0x9: return "V"
        case 0xd: return "W"
        case 0x7: return "X"
        case 0x10: return "Y"
        case 0x6: return "Z"
        default: return nil
        }
    }
}

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
    
    @Published var translationShortcut: KeyShortcut
    @Published var tabToggleShortcut: KeyShortcut
    
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
        
        if let data = storage.data(forKey: "translationShortcutData"),
           let decoded = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
            self.translationShortcut = decoded
        } else {
            self.translationShortcut = KeyShortcut(keyCode: KeyCode.Symbol.VK_BACKQUOTE, modifiers: UInt64(NSEvent.ModifierFlags.option.rawValue), displayName: "⌥ + `")
        }
        
        if let data = storage.data(forKey: "tabToggleShortcutData"),
           let decoded = try? JSONDecoder().decode(KeyShortcut.self, from: data) {
            self.tabToggleShortcut = decoded
        } else {
            self.tabToggleShortcut = KeyShortcut(keyCode: KeyCode.Special.VK_TAB, modifiers: 0, displayName: "TAB")
        }

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
        
        $translationShortcut.sink { [weak self] in 
            if let data = try? JSONEncoder().encode($0) {
                self?.storage.set(data, forKey: "translationShortcutData")
            }
            self?.post() 
        }.store(in: &cancellables)
        
        $tabToggleShortcut.sink { [weak self] in 
            if let data = try? JSONEncoder().encode($0) {
                self?.storage.set(data, forKey: "tabToggleShortcutData")
            }
            self?.post() 
        }.store(in: &cancellables)

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
