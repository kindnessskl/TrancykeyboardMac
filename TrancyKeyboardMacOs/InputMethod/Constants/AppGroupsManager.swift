import Foundation

class AppGroupsManager {
    static let shared = AppGroupsManager()

    private let fileManager = FileManager.default
    private var databasePathCache: [String: String] = [:]


    private var containerURL: URL? {
        #if os(macOS)
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let trancyPath = appSupport.appendingPathComponent("TrancyIM", isDirectory: true)
        
        if !fileManager.fileExists(atPath: trancyPath.path) {
            try? fileManager.createDirectory(at: trancyPath, withIntermediateDirectories: true, attributes: nil)
        }
        return trancyPath
        #else
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier)
        #endif
    }

    private init() {
        setupDirectories()
    }

    private func setupDirectories() {
        guard let containerURL = containerURL else { return }
        
        let directories = ["Cache", "Database"]
        for directory in directories {
            let dirURL = containerURL.appendingPathComponent(directory, isDirectory: true)
            if !fileManager.fileExists(atPath: dirURL.path) {
                try? fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    func getDatabaseURL(_ databaseName: String) -> URL? {
        return containerURL?.appendingPathComponent("Database").appendingPathComponent(databaseName)
    }

    func ensureDatabaseExists(_ databaseName: String, fromBundle bundleFileName: String? = nil) -> (path: String?, isNew: Bool) {
        if let cachedPath = databasePathCache[databaseName] {
            return (cachedPath, false)
        }
        
        guard let dbURL = getDatabaseURL(databaseName) else { return (nil, false) }

        if fileManager.fileExists(atPath: dbURL.path) {
            databasePathCache[databaseName] = dbURL.path
            return (dbURL.path, false)
        }

        let resourceName = bundleFileName ?? databaseName.replacingOccurrences(of: ".db", with: "")
        guard let bundlePath = Bundle.main.path(forResource: resourceName, ofType: "db") else {
            return (nil, false)
        }
        
        do {
            try fileManager.copyItem(atPath: bundlePath, toPath: dbURL.path)
            databasePathCache[databaseName] = dbURL.path
            return (dbURL.path, true)
        } catch {
            return (bundlePath, false)
        }
    }

    func getDatabasePath(_ databaseName: String) -> String? {
        return getDatabaseURL(databaseName)?.path
    }
}
