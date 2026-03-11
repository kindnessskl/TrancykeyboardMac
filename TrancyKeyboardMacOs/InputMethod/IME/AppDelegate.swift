import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    
    private override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("TrancyKeyboard: Application did finish launching.")
    }
}
