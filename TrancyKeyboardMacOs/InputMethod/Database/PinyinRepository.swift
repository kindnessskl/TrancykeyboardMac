import Foundation

enum ChineseOutputMode: Int, CaseIterable {
    case simplified = 0
    case traditional = 1
    
    var displayName: String {
        switch self {
        case .simplified: return "Chinese_Simplified".localized
        case .traditional: return "Chinese_Traditional".localized
        }
    }
    var wordColumn: String {
        return self == .simplified ? "word" : "word_trad"
    }
}

struct DatabaseConfig {
    #if USE_REAL_KEY
    static let password = RealSettings.password
    static let isDemo = false
    #else
    static let password = "demo_password"
    static let isDemo = true
    #endif
}

class PinyinRepository {
    static let shared = PinyinRepository()
    internal let database: DatabaseManager
    private(set) var isReady: Bool = false
    
    var outputMode: ChineseOutputMode {
        get {
            let val = SharedUserDefaults.shared.integer(forKey: "chineseOutputMode")
            return ChineseOutputMode(rawValue: val) ?? .simplified
        }
        set {
            SharedUserDefaults.shared.set(newValue.rawValue, forKey: "chineseOutputMode")
        }
    }
    
    private init() {
        let dbKey = DatabaseConfig.password
        let isDemo = DatabaseConfig.isDemo

        let actualDBName = isDemo ? "keyboard_demo.db" : AppConstants.Database.pinyinDBName
        let bundleFileName = isDemo ? "keyboard_demo" : "keyboard"

        let (path, _) = AppGroupsManager.shared.ensureDatabaseExists(
            actualDBName,
            fromBundle: bundleFileName
        )

        if let dbPath = path {
            database = DatabaseManager(dbPath: dbPath, password: isDemo ? nil : dbKey)
            isReady = database.open()
        } else {
            database = DatabaseManager(dbPath: "")
            isReady = false
        }
    }

    static func calculateScore(frequency: Int, updatedAt: Int, now: Int) -> Double {
        let baseScore = log(Double(max(1, frequency)))
        if updatedAt <= 0 { return baseScore }
        let diff = Double(max(0, now - updatedAt))
        return baseScore + 50.0 * exp(-diff / 3600.0) + 10.0 * exp(-diff / 259200.0)
    }

    internal func parseCandidates(_ results: [[String: Any]]) -> [Candidate] {
        return results.compactMap { row -> Candidate? in
            guard let text = row["text"] as? String else { return nil }
            return Candidate(
                text: text,
                pinyin: row["pinyin"] as? String ?? "",
                frequency: row["frequency"] as? Int ?? 0,
                updatedAt: row["updated_at"] as? Int ?? 0,
                type: text.count == 1 ? .character : .word,
                strokeCount: (row["stroke"] as? String ?? "").count
            )
        }
    }

    internal func processJoinResults(_ results: [[String: Any]]) -> ([Candidate], [[String]]) {
        var candidatesDict: [Int: Candidate] = [:]
        var translationsDict: [Int: [String]] = [:]
        var orderedIds: [Int] = []

        for result in results {
            guard let id = result["id"] as? Int else { continue }

            if candidatesDict[id] == nil {
                let text = result["text"] as! String
                candidatesDict[id] = Candidate(
                    text: text,
                    pinyin: result["pinyin"] as! String,
                    frequency: result["frequency"] as! Int,
                    updatedAt: result["updated_at"] as? Int ?? 0,
                    type: text.count == 1 ? .character : .word,
                    strokeCount: (result["stroke"] as? String ?? "").count
                )
                orderedIds.append(id)
            }

            if let translation = result["translation"] as? String {
                if translationsDict[id] == nil { translationsDict[id] = [] }
                if (translationsDict[id]?.count ?? 0) < 1 && !(translationsDict[id]?.contains(translation) ?? false) {
                    translationsDict[id]?.append(translation)
                }
            }
        }

        let candidates = orderedIds.compactMap { candidatesDict[$0] }
        let translations = orderedIds.map { translationsDict[$0] ?? [] }
        return (candidates, translations)
    }

    internal func handleOptimizedResults(_ results: [[String: Any]], withTranslations: Bool) -> ([Candidate], [[String]]?) {
        var candidates: [Candidate] = []
        var translations: [[String]] = []

        for row in results {
            let text = row["text"] as? String ?? ""
            let stroke = row["stroke"] as? String ?? ""
            let cand = Candidate(
                text: text,
                pinyin: row["pinyin"] as? String ?? "",
                frequency: row["frequency"] as? Int ?? 0,
                updatedAt: row["updated_at"] as? Int ?? 0,
                type: text.count == 1 ? .character : .word,
                strokeCount: stroke.count
            )
            candidates.append(cand)

            if withTranslations {
                let transRaw = row["translations"] as? String ?? ""
                translations.append(transRaw.isEmpty ? [] : transRaw.components(separatedBy: "||"))
            }
        }
        return (candidates, withTranslations ? translations : nil)
    }

    internal func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
