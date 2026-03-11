import Foundation
import Carbon

final class TrancyInstaller {
    private let bundleURL: CFURL = Bundle.main.bundleURL as CFURL
    private let inputSourceID = "com.trancy.inputmethod.TrancyIM.Hans"

    func register() {
        let status = TISRegisterInputSource(bundleURL)
        NSLog("TrancyKeyboard: Registration status: \(status)")
    }

    func activate() {
        guard let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as? [TISInputSource] else {
            NSLog("TrancyKeyboard: ❌ Error: Could not create input source list")
            return
        }

        for source in list {
            guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
            
            if id == inputSourceID || id == "com.trancy.inputmethod.TrancyIM" {
                TISEnableInputSource(source)
                TISSelectInputSource(source)
                NSLog("TrancyKeyboard: ✅ Successfully enabled and selected: \(id)")
            }
        }
    }
}
