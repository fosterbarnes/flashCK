import AppKit
import SwiftUI

/// Background accessor: gives the hosting window a transparent title bar on the app background and
/// reports the window to `onWindow` (the main window registers itself with the model this way).
struct WindowChrome: NSViewRepresentable {
    var onWindow: ((NSWindow) -> Void)?

    func makeNSView(context: Context) -> ChromeView { ChromeView() }

    func updateNSView(_ view: ChromeView, context: Context) {
        view.onWindow = onWindow
        view.apply()
    }

    final class ChromeView: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            guard let window else { return }
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Color.appBackground)
            onWindow?(window)
        }
    }
}
