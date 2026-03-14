import Foundation

extension String {
    var localized: String {
        var languageCode = SharedUserDefaults.shared.string(forKey: "appLanguage")
        if languageCode == nil {
            let preferredLang = Locale.preferredLanguages.first ?? ""
            if preferredLang.hasPrefix("zh-Hant") || preferredLang.hasPrefix("zh-HK") || preferredLang.hasPrefix("zh-TW") {
                languageCode = "zh-Hant"
            } else {
                languageCode = "zh-Hans"
            }
        }
        let code = languageCode ?? "zh-Hans"

        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(self, tableName: nil, bundle: bundle, value: self, comment: "")
        }

        let bundle = Bundle(for: SharedUserDefaults.self)
        if let path = bundle.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return NSLocalizedString(self, tableName: nil, bundle: langBundle, value: self, comment: "")
        }

        return NSLocalizedString(self, value: self, comment: "")
    }
    
    func localized(with comment: String = "") -> String {
        return self.localized
    }
}
