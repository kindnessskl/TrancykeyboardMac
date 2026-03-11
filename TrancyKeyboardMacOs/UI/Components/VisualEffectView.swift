import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    var cornerRadius: CGFloat = 8.0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true

        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.layer?.cornerRadius = cornerRadius
    }
}
