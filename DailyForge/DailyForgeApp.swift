import SwiftUI
import SwiftData
import AppKit
import UserNotifications

@main
struct DailyForgeApp: App {
    @NSApplicationDelegateAdaptor(DailyForgeAppDelegate.self) var appDelegate
    let container: ModelContainer
    let startupError: String?

    init() {
        Preferences.registerDefaults()

        let schema = Schema([
            Exercise.self,
            CompletionRecord.self,
            DayLock.self,
            DailySwear.self,
            UserProfile.self,
            Milestone.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
            self.startupError = nil
            return
        } catch {
            print("⚠️ ModelContainer init failed: \(error)")
            print("⚠️ Wiping store and retrying…")
        }

        Self.wipeStore()

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
            self.startupError = nil
        } catch {
            print("❌ Still failing after wipe: \(error)")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let memoryContainer = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
                self.container = memoryContainer
                self.startupError = "Could not open the on-disk database. Running with temporary storage. \(error.localizedDescription)"
            } else {
                fatalError("Schema is invalid: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let startupError {
                    StartupErrorView(message: startupError)
                } else {
                    RootView()
                }
            }
            .onAppear {
                DailyForgeAppDelegate.sharedContainer = container
            }
        }
        .modelContainer(container)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") { PreferencesOpener.open() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private static func wipeStore() {
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            removeStoreFiles(in: appSupport, named: "default", fm: fm)
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            let containerURL = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers")
                .appendingPathComponent(bundleID)
                .appendingPathComponent("Data/Library/Application Support")
            removeStoreFiles(in: containerURL, named: "default", fm: fm)
        }
    }

    private static func removeStoreFiles(in directory: URL, named base: String, fm: FileManager) {
        for suffix in ["", "-shm", "-wal"] {
            let url = directory.appendingPathComponent("\(base).store\(suffix)")
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }
    }
}

// MARK: - Preferences Opener

enum PreferencesOpener {
    private static var controller: PreferencesWindowController?

    static func open() {
        if controller == nil {
            controller = PreferencesWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - AppDelegate

class DailyForgeAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    static var sharedContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.bootstrap()
        NotificationManager.shared.requestPermission()

        EnforcementController.shared.start()
        setupMenuBar()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let container = DailyForgeAppDelegate.sharedContainer else { return }
            EnforcementController.shared.handleLaunch(container: container)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Blocks Quit while the overlay is engaged OR while the swear sheet
    /// is open. The user must finish the swear to escape.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if OverlayEnforcer.shared.isActive || SwearSessionState.shared.isActive {
            NSSound(named: "Basso")?.play()
            return .terminateCancel
        }
        return .terminateNow
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "figure.strengthtraining.traditional",
                accessibilityDescription: "DailyForge"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Open DailyForge",
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit DailyForge",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        for item in menu.items { item.target = self }
        statusItem?.menu = menu
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.level == .normal && window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }

    @objc private func openPreferences() {
        PreferencesOpener.open()
    }
}

// MARK: - Fallback error UI

struct StartupErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Storage issue").font(.title.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            HStack(spacing: 12) {
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut(.cancelAction)
                Button("Try Again") { NSApp.terminate(nil) }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(minWidth: 480, minHeight: 320)
    }
}
