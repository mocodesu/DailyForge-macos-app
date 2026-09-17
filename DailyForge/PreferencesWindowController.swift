import AppKit
import SwiftUI

class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let hostingController = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "DailyForge Preferences"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 680, height: 720))
        window.minSize = NSSize(width: 620, height: 560)
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        EnforcementController.shared.refresh()
        sender.orderOut(nil)
        return false
    }
}
