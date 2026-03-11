import SwiftUI
import Combine

struct FuzzyPinyinOption {
    let key: String
    let displayName: String
    let description: String
    let category: String
}

class FuzzyPinyinStore: ObservableObject {
    @Published var options: [FuzzyPinyinOption] = []
    
    init() {
        loadOptions()
    }
    
    func isEnabled(for option: FuzzyPinyinOption) -> Bool {
        return SharedUserDefaults.shared.bool(forKey: option.key)
    }
    
    func setEnabled(_ enabled: Bool, for option: FuzzyPinyinOption) {
        SharedUserDefaults.shared.set(enabled, forKey: option.key)
        objectWillChange.send()
        NotificationCenter.default.post(name: .keyboardSettingsDidChange, object: nil)
    }
    
    private func loadOptions() {
        options = [
            FuzzyPinyinOption(key: "fuzzy_zh_z", displayName: "zh-z", description: "知-资", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_ch_c", displayName: "ch-c", description: "吃-慈", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_sh_s", displayName: "sh-s", description: "诗-私", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_l_n", displayName: "l-n", description: "来-奈", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_p_b", displayName: "p-b", description: "胖-搬", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_t_d", displayName: "t-d", description: "推-堆", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_q_c", displayName: "q-c", description: "七-次", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_r_n", displayName: "r-n", description: "软-暖", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_r_l", displayName: "r-l", description: "软-乱", category: "声母"),
            FuzzyPinyinOption(key: "fuzzy_f_h", displayName: "f-h", description: "飞-黑", category: "声母"),
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
            
            FuzzyPinyinOption(key: "fuzzy_v_u_conversion", displayName: "v-u", description: "ü和u互转", category: "其他"),
        ]
    }
}

struct FuzzyPinyinSettingsView: View {
    @StateObject private var store = FuzzyPinyinStore()
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                let categorizedOptions = Dictionary(grouping: store.options) { $0.category }
                let categoryOrder = ["声母", "韵母", "音节", "其他"]
                
                ForEach(categoryOrder, id: \.self) { category in
                    if let options = categorizedOptions[category], !options.isEmpty {
                        Section(header: Text(category)) {
                            ForEach(options, id: \.key) { option in
                                Toggle(isOn: Binding(
                                    get: { store.isEnabled(for: option) },
                                    set: { store.setEnabled($0, for: option) }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.displayName)
                                            .font(.system(size: 13, weight: .medium))
                                        Text(option.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(IOSToggleStyle())
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetListStyle())
        }
        .frame(width: 300, height: 700)
    }
}
