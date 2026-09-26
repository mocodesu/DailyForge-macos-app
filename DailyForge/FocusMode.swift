import Foundation
import AppKit

final class FocusModeManager {
    static let shared = FocusModeManager()

    private var isActive = false
    private var savedPresentation: NSApplication.PresentationOptions?
    private var shortcutProcess: Process?

    private init() {}

    // MARK: Public

    /// Enters focus mode. Called when a workout session begins.
    /// Honors the user's preferences for whether it's enabled, what it
    /// hides, and what Shortcut to run.
    func engage() {
        guard !isActive else { return }
        guard UserDefaults.standard.bool(forKey: PreferenceKeys.focusModeEnabled) else { return }

        isActive = true
        savedPresentation = NSApp.presentationOptions

        var options: NSApplication.PresentationOptions = []
        if UserDefaults.standard.bool(forKey: PreferenceKeys.focusHideDockAndMenuBar) {
            options.insert(.hideDock)
            options.insert(.hideMenuBar)
        }
        NSApp.presentationOptions = options

        runShortcut(named: UserDefaults.standard.string(forKey: PreferenceKeys.focusShortcutName))
    }

    /// Exits focus mode. Called when the session ends or the view disappears.
    func release() {
        guard isActive else { return }
        isActive = false

        if let saved = savedPresentation {
            NSApp.presentationOptions = saved
            savedPresentation = nil
        }

        shortcutProcess?.terminate()
        shortcutProcess = nil
    }

    /// True while focus mode is active. Exposed for UI.
    var active: Bool { isActive }

    /// Runs a named Shortcut in the background. No-op if the name is empty.
    /// Errors are logged but never surfaced — this is a best-effort side
    /// channel that shouldn't interrupt a workout.
    private func runShortcut(named: String?) {
        guard let name = named?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            shortcutProcess = process
        } catch {
            print("⚠️ FocusMode: could not run Shortcut '\(name)': \(error.localizedDescription)")
        }
    }
}
