import AppKit
import SwiftUI

class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let hostingController = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "DailyForge Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 580, height: 620))
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Force the enforcement layer to re-evaluate with the new prefs
        // the instant the user dismisses the window.
        EnforcementController.shared.refresh()
        sender.orderOut(nil)
        return false
    }
}
