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

        StoreBackup.autoBackupIfNeeded()

        let schema = Schema([
            Exercise.self,
            CompletionRecord.self,
            DayLock.self,
            DailySwear.self,
            UserProfile.self,
            Milestone.self,
            StreakFreeze.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
            self.startupError = nil
            return
        } catch {
            let diskError = error
            print("❌ ModelContainer init failed: \(diskError)")
            print("❌ Store NOT wiped. Open Preferences → Data to restore or wipe manually.")

            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let memoryContainer = try? ModelContainer(for: schema, configurations: [memoryConfig]) else {
                fatalError("Schema is invalid: \(diskError)")
            }
            self.container = memoryContainer
            self.startupError = """
            Could not open your store.

            Your data is still on disk at ~/Library/Application Support/default.store — it has NOT been touched.

            Open Preferences → Data (Cmd+,) to restore a backup, wipe the store, or export your data.

            \(diskError.localizedDescription)
            """
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
            .tint(Theme.accentFill)
            .background(Theme.surfaceBase)
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
        menu.addItem(NSMenuItem(
            title: "Manage Data…",
            action: #selector(openPreferences),
            keyEquivalent: "d"
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit DailyForge",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        for item in menu.items where item.action != nil { item.target = self }
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
                .foregroundStyle(Theme.warning)
            Text("Storage issue").font(.title.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut(.cancelAction)
                Button("Manage Data…") {
                    PreferencesOpener.open()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(minWidth: 560, minHeight: 360)
        .background(Theme.surfaceBase)
    }
}
