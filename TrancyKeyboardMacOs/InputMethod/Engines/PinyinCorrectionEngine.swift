import Foundation

class PinyinCorrectionEngine {
    static let shared = PinyinCorrectionEngine()
    private let validator = PinyinValidator.shared
    private static let zhChShPattern1 = try! NSRegularExpression(pattern: "^h([zcs])(a|e|i|u|ai|ei|an|en|ou|uo|ua|un|ui|uan|uai|uang|ang|eng|ong)$")
    private static let zhChShPattern2 = try! NSRegularExpression(pattern: "^([zcs])([aeiu])h$")
    
    private static let oPattern = try! NSRegularExpression(pattern: "^([rtsdghkzc])o$")
    private static let onPattern = try! NSRegularExpression(pattern: "^(.+)on$")
    private static let tlPattern = try! NSRegularExpression(pattern: "^([tl])en$")
    private static let ngPattern = try! NSRegularExpression(pattern: "^([qwrtypsdfghjklzxcbnm])ng$")
    
    var isAutoCorrectEnabled: Bool = false
    var isKeyboardCorrectEnabled: Bool = false
    private var enabledFuzzyKeys: Set<String> = []
    
    private init() {
        initializeFuzzyPinyinDefaults()
        refreshSettings()
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .keyboardSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshSettings()
        }
    }

    func refreshSettings() {
        let defaults = SharedUserDefaults.shared
        isAutoCorrectEnabled = defaults.bool(forKey: "isAutoCorrectEnabled")
        isKeyboardCorrectEnabled = defaults.bool(forKey: "isKeyboardCorrectEnabled")
        
        var keys = Set<String>()
        let options = getAllFuzzyPinyinOptions()
        for option in options {
            if defaults.bool(forKey: option.key) {
                keys.insert(option.key)
            }
        }
        self.enabledFuzzyKeys = keys
    }

    func applyCorrections(_ input: String) -> String {
        guard isAutoCorrectEnabled else { return input }
        if let corrected = performAutoCorrect(input) { return corrected }
        return input
    }
    
    private func performAutoCorrect(_ input: String) -> String? {
        if let corrected = applyZhChShRules(input) { return corrected }
        if let corrected = applySpecialRules(input) { return corrected }
        return nil
    }

    func generateOnlyFuzzyPinyinVariants(_ input: String) -> [String] {
        return generateFuzzyPinyinVariants(input)
    }
    
    func generateAutoCorrectionVariants(_ input: String, isEnabled: Bool) -> [String] {
        guard isEnabled else { return [] }
        if let corrected = performAutoCorrect(input) { return [corrected] }
        return []
    }
    
    func generateOnlyKeyboardCorrectionVariants(_ input: String, isEnabled: Bool) -> [String] {
        guard isEnabled, input.count > 1 else { return [] }
        return generateKeyboardFuzzyVariants(input)
    }
    
    func hasAnyFuzzyPinyinEnabled() -> Bool {
        return !enabledFuzzyKeys.isEmpty
    }
    
    func generateKeyboardCorrectionVariants(_ input: String) -> [String] {
        var variants: [String] = []
        if isKeyboardCorrectEnabled && input.count > 1 {
            variants.append(contentsOf: generateKeyboardFuzzyVariants(input))
        }
        return Array(Set(variants))
    }
    
    private func generateFuzzyPinyinVariants(_ input: String) -> [String] {
        var variants = Set<String>()
        if enabledFuzzyKeys.contains("fuzzy_zh_z") { applyZhZFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_ch_c") { applyChCFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_sh_s") { applyShSFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_l_n") { applyLNFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_p_b") { applyPBFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_t_d") { applyTDFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_q_c") { applyQCFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_r_n") { applyRNFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_f_h") { applyFHFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_l_r") { applyLRFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_g_k") { applyGKFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_ang_an") { applyAngAnFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_eng_en") { applyEngEnFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_in_ing") { applyInIngFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_ian_iang") { applyIanIangFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_uan_uang") { applyUanUangFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_e_i") { applyEIFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_ai_an") { applyAiAnFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_ong_un") { applyOngUnFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_ong_eng") { applyOngEngFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_iong_un") { applyIongUnFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_fei_hui") { applyFeiHuiFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_hu_fu") { applyHuFuFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_wang_huang") { applyWangHuangFuzzy(input, &variants) }
        if enabledFuzzyKeys.contains("fuzzy_v_u_conversion") { applyVUConversion(input, &variants) }
        return Array(variants).filter { !$0.isEmpty && $0 != input }
    }

    private func applyZhChShRules(_ input: String) -> String? {
        let range = NSRange(location: 0, length: input.utf16.count)
        let corrected1 = PinyinCorrectionEngine.zhChShPattern1.stringByReplacingMatches(in: input, range: range, withTemplate: "$1h$2")
        if corrected1 != input && validator.isValid(corrected1) { return corrected1 }
        let corrected2 = PinyinCorrectionEngine.zhChShPattern2.stringByReplacingMatches(in: input, range: range, withTemplate: "$1h$2")
        if corrected2 != input && validator.isValid(corrected2) { return corrected2 }
        return nil
    }
    
    private func applySpecialRules(_ input: String) -> String? {
        let range = NSRange(location: 0, length: input.utf16.count)
        if PinyinCorrectionEngine.oPattern.firstMatch(in: input, options: [], range: range) != nil {
            let ouCorrected = PinyinCorrectionEngine.oPattern.stringByReplacingMatches(in: input, range: range, withTemplate: "$1ou")
            if validator.isValid(ouCorrected) { return ouCorrected }
            let ongCorrected = PinyinCorrectionEngine.oPattern.stringByReplacingMatches(in: input, range: range, withTemplate: "$1ong")
            if validator.isValid(ongCorrected) { return ongCorrected }
        }
        let onCorrected = PinyinCorrectionEngine.onPattern.stringByReplacingMatches(in: input, range: range, withTemplate: "$1ong")
        if onCorrected != input && validator.isValid(onCorrected) { return onCorrected }
        let tlCorrected = PinyinCorrectionEngine.tlPattern.stringByReplacingMatches(in: input, range: range, withTemplate: "$1eng")
        if tlCorrected != input && validator.isValid(tlCorrected) { return tlCorrected }
        if PinyinCorrectionEngine.ngPattern.firstMatch(in: input, options: [], range: range) != nil {
            let ngSuffixes = ["ang", "eng", "ing", "ong"]
            for suffix in ngSuffixes {
                let ngCorrected = PinyinCorrectionEngine.ngPattern.stringByReplacingMatches(in: input, range: range, withTemplate: "$1\(suffix)")
                if validator.isValid(ngCorrected) { return ngCorrected }
            }
        }
        return nil
    }

    private func isPossibleSyllableOrInitial(_ s: String) -> Bool {
        if validator.isValid(s) { return true }
        let initials = ["zh", "ch", "sh", "z", "c", "s", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "y", "w"]
        return initials.contains(s.lowercased())
    }

    private func applyZhZFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("zh") { let v = "z" + String(input.dropFirst(2)); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("z") { let v = "zh" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyChCFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("ch") { let v = "c" + String(input.dropFirst(2)); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("c") { let v = "ch" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyShSFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("sh") { let v = "s" + String(input.dropFirst(2)); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("s") { let v = "sh" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyAngAnFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("ang") { let v = String(input.dropLast(3)) + "an"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("an") { let v = String(input.dropLast(2)) + "ang"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyEngEnFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("eng") { let v = String(input.dropLast(3)) + "en"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("en") { let v = String(input.dropLast(2)) + "eng"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyInIngFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("ing") { let v = String(input.dropLast(3)) + "in"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("in") { let v = String(input.dropLast(2)) + "ing"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyIanIangFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("iang") { let v = String(input.dropLast(4)) + "ian"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("ian") { let v = String(input.dropLast(3)) + "iang"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyUanUangFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("uang") { let v = String(input.dropLast(4)) + "uan"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("uan") { let v = String(input.dropLast(3)) + "uang"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyEIFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("e") { let v = String(input.dropLast()) + "i"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("i") { let v = String(input.dropLast()) + "e"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyIongUnFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("iong") { let v = String(input.dropLast(4)) + "un"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("un") { let p = String(input.dropLast(2)); if ["j", "q", "x"].contains(p) { let v = p + "iong"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } } }
    }
    private func applyLNFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("l") { let v = "n" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("n") { let v = "l" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyPBFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("p") { let v = "b" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("b") { let v = "p" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyTDFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("t") { let v = "d" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("d") { let v = "t" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyQCFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("q") { let v = "c" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("c") && !input.hasPrefix("ch") { let v = "q" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyRNFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("r") { let v = "n" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("n") { let v = "r" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyFHFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("f") { let v = "h" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("h") { let v = "f" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyLRFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("l") { let v = "r" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("r") { let v = "l" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyGKFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasPrefix("g") { let v = "k" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasPrefix("k") { let v = "g" + String(input.dropFirst()); if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyAiAnFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("ai") { let v = String(input.dropLast(2)) + "an"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("an") && !input.hasSuffix("ang") { let v = String(input.dropLast(2)) + "ai"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyOngUnFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("ong") { let v = String(input.dropLast(3)) + "un"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("un") { let v = String(input.dropLast(2)) + "ong"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyOngEngFuzzy(_ input: String, _ variants: inout Set<String>) {
        if input.hasSuffix("ong") { let v = String(input.dropLast(3)) + "eng"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
        else if input.hasSuffix("eng") { let v = String(input.dropLast(3)) + "ong"; if isPossibleSyllableOrInitial(v) { variants.insert(v) } }
    }
    private func applyFeiHuiFuzzy(_ input: String, _ variants: inout Set<String>) { if input == "fei" { variants.insert("hui") } else if input == "hui" { variants.insert("fei") } }
    private func applyHuFuFuzzy(_ input: String, _ variants: inout Set<String>) { if input == "hu" { variants.insert("fu") } else if input == "fu" { variants.insert("hu") } }
    private func applyWangHuangFuzzy(_ input: String, _ variants: inout Set<String>) { if input == "wang" { variants.insert("huang") } else if input == "huang" { variants.insert("wang") } }
 
    private func applyVUConversion(_ input: String, _ variants: inout Set<String>) {
        for s in ["j", "q", "x"] {
            if input.hasPrefix("\(s)v") {
                let v = "\(s)u" + String(input.dropFirst(2))
                if isPossibleSyllableOrInitial(v) { variants.insert(v) }
            }
        }
    }

    struct FuzzyPinyinOption {
        let key: String
        let displayName: String
        let description: String
        let category: String
    }

    func getAllFuzzyPinyinOptions() -> [FuzzyPinyinOption] {
        return [
            FuzzyPinyinOption(key: "fuzzy_zh_z", displayName: "zh-z", description: "知-资", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_ch_c", displayName: "ch-c", description: "吃-此", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_sh_s", displayName: "sh-s", description: "是-思", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_l_n", displayName: "l-n", description: "来-奶", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_p_b", displayName: "p-b", description: "胖-搬", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_t_d", displayName: "t-d", description: "推-堆", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_q_c", displayName: "q-c", description: "七-次", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_r_n", displayName: "r-n", description: "软-暖", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_f_h", displayName: "f-h", description: "飞-黑", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_l_r", displayName: "l-r", description: "乱-软", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_g_k", displayName: "g-k", description: "哥-科", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_ang_an", displayName: "ang-an", description: "张-站", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_eng_en", displayName: "eng-en", description: "生-森", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_in_ing", displayName: "in-ing", description: "因-英", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_ian_iang", displayName: "ian-iang", description: "年-娘", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_uan_uang", displayName: "uan-uang", description: "关-光", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_e_i", displayName: "e-i", description: "了-里", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_ai_an", displayName: "ai-an", description: "买-慢", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_ong_un", displayName: "ong-un", description: "中-春", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_ong_eng", displayName: "ong-eng", description: "中-生", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_iong_un", displayName: "iong-un", description: "雄-春", category: "韵母"),
            FuzzyPinyinOption(key: "fuzzy_fei_hui", displayName: "fei-hui", description: "飞-会", category: "音节"),
            FuzzyPinyinOption(key: "fuzzy_hu_fu", displayName: "hu-fu", description: "湖-福", category: "音节"),
            FuzzyPinyinOption(key: "fuzzy_wang_huang", displayName: "wang-huang", description: "王-黄", category: "音节"),
            FuzzyPinyinOption(key: "fuzzy_v_u_conversion", displayName: "v-u", description: "ü和u互转", category: "其他")
        ]
    }

    private func initializeFuzzyPinyinDefaults() {
        let defaults = SharedUserDefaults.shared
        if !defaults.bool(forKey: "fuzzy_initialized") {
            let keys = ["fuzzy_zh_z", "fuzzy_ch_c", "fuzzy_sh_s", "fuzzy_l_n", "fuzzy_p_b", "fuzzy_t_d", "fuzzy_q_c", "fuzzy_r_n", "fuzzy_f_h", "fuzzy_l_r", "fuzzy_g_k", "fuzzy_ang_an", "fuzzy_eng_en", "fuzzy_in_ing", "fuzzy_ian_iang", "fuzzy_uan_uang", "fuzzy_e_i", "fuzzy_ai_an", "fuzzy_ong_un", "fuzzy_ong_eng", "fuzzy_iong_un", "fuzzy_fei_hui", "fuzzy_hu_fu", "fuzzy_wang_huang", "fuzzy_v_u_conversion", "fuzzy_old_spelling"]
            for key in keys { defaults.set(false, forKey: key) }
            defaults.set(true, forKey: "fuzzy_initialized")
        }
    }

    func generateKeyboardFuzzyVariants(_ input: String) -> [String] {
        let keyboardMap: [Character: [Character]] = ["q": ["w", "a"], "w": ["q", "e"], "e": ["w", "r"], "r": ["e", "t"], "t": ["r", "y"], "y": ["t", "u"], "u": ["y", "i"], "i": ["u", "o"], "o": ["i", "p"], "p": ["o", "l"], "a": ["q", "s"], "s": ["d"], "d": ["s", "f"], "f": ["d", "g"], "g": ["f", "h"], "h": ["g", "j"], "j": ["h", "k"], "k": ["j", "l"], "l": ["k"], "z": ["a", "x"], "x": ["z", "c"], "c": ["x"], "v": ["c", "b"], "b": ["v", "n"], "n": ["b", "m"], "m": ["n"]]
        var variants: [String] = []
        let chars = Array(input)
        for i in 0..<chars.count {
            if let neighbors = keyboardMap[chars[i]] {
                for neighbor in neighbors {
                    var newChars = chars
                    newChars[i] = neighbor
                    let variant = String(newChars)
                    if validator.isValid(variant) { variants.append(variant) }
                    if variants.count >= 5 { return variants }
                }
            }
        }
        return variants
    }
}
