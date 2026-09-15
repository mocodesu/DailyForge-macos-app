import SwiftUI
import SwiftData

@main
struct DailyForgeApp: App {
    let container: ModelContainer
    let startupError: String?

    init() {
        let schema = Schema([
            Exercise.self,
            CompletionRecord.self,
            DayLock.self,
            UserProfile.self,
            Milestone.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // First attempt: open the existing store
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
            self.startupError = nil
            return
        } catch {
            print("⚠️ ModelContainer init failed: \(error)")
            print("⚠️ Wiping store and retrying…")
        }

        // Second attempt: wipe the store, then retry
        Self.wipeStore()

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
            self.startupError = nil
        } catch {
            // Third attempt: fall back to an in-memory container so the app
            // still opens and can tell the user what's wrong.
            print("❌ Still failing after wipe: \(error)")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let memoryContainer = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
                self.container = memoryContainer
                self.startupError = "Could not open the on-disk database. Running with temporary storage — changes will not be saved. \(error.localizedDescription)"
            } else {
                // This is genuinely unrecoverable — the schema itself is broken.
                // We cannot continue without a container, so this is one of the
                // very few legitimate uses of fatalError.
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
        }
        .modelContainer(container)
        .windowResizability(.contentMinSize)
    }

    // MARK: - Store wiping

    /// Deletes all files SwiftData/`CoreData` uses to back the default store.
    /// Safe to call when the app has no open container yet.
    private static func wipeStore() {
        let fm = FileManager.default

        // Non-sandboxed default location: ~/Library/Application Support/
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            removeStoreFiles(in: appSupport, named: "default", fm: fm)
        }

        // Sandboxed container location (in case the app is ever sandboxed)
        if let bundleID = Bundle.main.bundleIdentifier {
            let containerURL = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers")
                .appendingPathComponent(bundleID)
                .appendingPathComponent("Data/Library/Application Support")
            removeStoreFiles(in: containerURL, named: "default", fm: fm)
        }
    }

    private static func removeStoreFiles(in directory: URL, named base: String, fm: FileManager) {
        let suffixes = ["", "-shm", "-wal"]
        for suffix in suffixes {
            let url = directory.appendingPathComponent("\(base).store\(suffix)")
            if fm.fileExists(atPath: url.path) {
                do {
                    try fm.removeItem(at: url)
                    print("🗑️ Removed \(url.lastPathComponent)")
                } catch {
                    print("⚠️ Could not remove \(url.lastPathComponent): \(error)")
                }
            }
        }
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

            Text("Storage issue")
                .font(.title.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut(.cancelAction)

                Button("Try Again") {
                    // Quit — the next launch will retry the whole init sequence
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(minWidth: 480, minHeight: 320)
    }
}
