import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    var floating: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.level = floating ? .floating : .normal
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.minSize = NSSize(width: 320, height: 420)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
    }
}
