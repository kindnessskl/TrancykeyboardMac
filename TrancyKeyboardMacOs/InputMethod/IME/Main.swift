import AppKit
import InputMethodKit

@main
struct TrancyApp {
    static func main() {
        let handled = autoreleasepool {
            let args = CommandLine.arguments
            if args.count > 1 {
                if args.contains("--quit") {
                    let bundleId = Bundle.main.bundleIdentifier ?? "com.trancy.inputmethod.TrancyIM"
                    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                    apps.forEach { $0.terminate() }
                    return true
                }
                
                let installer = TrancyInstaller()
                if args.contains("--register") {
                    installer.register()
                    return true
                }
                if args.contains("--activate") {
                    installer.activate()
                    return true
                }
                if args.contains("--install") {
                    installer.register()
                    installer.activate()
                    return true
                }
            }
            return false
        }

        if handled { return }

        autoreleasepool {
            let bundle = Bundle.main
            let connectionName = bundle.infoDictionary?["InputMethodConnectionName"] as? String ?? "TrancyIM_1_Connection"
            
            _ = IMKServer(name: connectionName, bundleIdentifier: bundle.bundleIdentifier)
            
            let app = NSApplication.shared
            let delegate = AppDelegate.shared
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            
            app.run()
        }
    }
}
