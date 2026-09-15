import AppKit
import SwiftUI

class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let hostingController = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "DailyForge Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 540, height: 440))
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)

        window.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of closing so the window can be reopened quickly
        sender.orderOut(nil)
        return false
    }
}
