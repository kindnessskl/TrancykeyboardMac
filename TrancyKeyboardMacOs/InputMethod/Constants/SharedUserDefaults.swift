import Foundation

class SharedUserDefaults {
    static let shared = SharedUserDefaults()
    static let databaseVersionKey = "DB_DATA_VERSION"
    
    private let userDefaults: UserDefaults
    
    private init() {
        self.userDefaults = UserDefaults(suiteName: "group.com.trancy.keyboard") ?? UserDefaults.standard
    }
    
    func getDatabaseVersion() -> String {
        return string(forKey: SharedUserDefaults.databaseVersionKey) ?? "1"
    }
    
    func setDatabaseVersion(_ version: String) {
        set(version, forKey: SharedUserDefaults.databaseVersionKey)
    }
    
    func set(_ value: Any?, forKey key: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }
    
    func string(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }
    
    func bool(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }
    
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if userDefaults.object(forKey: key) == nil {
            return defaultValue
        }
        return userDefaults.bool(forKey: key)
    }
    func integer(forKey key: String, defaultValue: Int) -> Int {
        if userDefaults.object(forKey: key) == nil {
            return defaultValue
        }
        return userDefaults.integer(forKey: key)
    }
    func object(forKey key: String) -> Any? {
        return userDefaults.object(forKey: key)
    }
    
    func data(forKey key: String) -> Data? {
        return userDefaults.data(forKey: key)
    }
    
    func integer(forKey key: String) -> Int {
        return userDefaults.integer(forKey: key)
    }
    
    func float(forKey key: String) -> Float {
        return userDefaults.float(forKey: key)
    }
    
    func float(forKey key: String, defaultValue: Float) -> Float {
        if userDefaults.object(forKey: key) == nil {
            return defaultValue
        }
        return userDefaults.float(forKey: key)
    }
    
    func cgFloat(forKey key: String, defaultValue: CGFloat) -> CGFloat {
        return CGFloat(float(forKey: key, defaultValue: Float(defaultValue)))
    }
    
    func synchronize() {
        userDefaults.synchronize()
    }
}
