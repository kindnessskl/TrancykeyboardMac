import Foundation

extension String {
    var localized: String {
        let languageCode = SharedUserDefaults.shared.string(forKey: "appLanguage") ?? "zh-Hans"
        
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(self, tableName: nil, bundle: bundle, value: self, comment: "")
        }
        
        let bundle = Bundle(for: AppGroupsManager.self)
        if let path = bundle.path(forResource: languageCode, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return NSLocalizedString(self, tableName: nil, bundle: langBundle, value: self, comment: "")
        }
        
        return NSLocalizedString(self, value: self, comment: "")
    }
    
    func localized(with comment: String = "") -> String {
        return self.localized
    }
}
