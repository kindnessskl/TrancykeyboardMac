import Foundation
struct AppConstants {
    static let appGroupIdentifier = "group.com.trancy.keyboard"
    static let mainAppBundleID = "com.liangshankang.TrancyKeyboard"
    static let keyboardExtensionBundleID = "com.liangshankang.TrancyKeyboard.Extension"
    struct Database {
        static let pinyinDBName = "keyboard.db"
        static let icloudContainerIdentifier = "iCloud.com.kindness.trancy"
    }
    static func getAppGroupsURL() -> URL? {
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }
    static func getDatabaseURL(name: String) -> URL? {
        return getAppGroupsURL()?.appendingPathComponent(name)
    }
    static func getSharedFileURL(name: String) -> URL? {
        return getAppGroupsURL()?.appendingPathComponent(name)
    }
}
