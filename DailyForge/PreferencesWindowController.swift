import AppKit
import SwiftUI

class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let hostingController = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: hostingController)

        window.title = "DailyForge Preferences"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 720, height: 760))
        window.minSize = NSSize(width: 680, height: 620)
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(Theme.surfaceBase)

        // Align the traffic lights with our content padding.
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        self.init(window: window)
        window.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        EnforcementController.shared.refresh()
        sender.orderOut(nil)
        return false
    }
}
