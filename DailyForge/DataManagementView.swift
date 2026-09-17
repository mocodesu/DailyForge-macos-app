import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var context

    @State private var backups: [BackupInfo] = []
    @State private var activeStoreSize: Int64 = 0
    @State private var totalBackupSize: Int64 = 0
    @State private var isBusy = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    @State private var restoreCandidate: BackupInfo?
    @State private var showWipeConfirmation = false
    @State private var showResetPrefsConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                storageInfo
                quickActions
                backupList
                statusBar
                #if DEBUG
                dangerZone
                #endif
            }
            .padding(24)
        }
        .onAppear(perform: refresh)
        .confirmationDialog(
            "Restore from this backup?",
            isPresented: Binding(
                get: { restoreCandidate != nil },
                set: { if !$0 { restoreCandidate = nil } }
            ),
            titleVisibility: .visible,
            presenting: restoreCandidate
        ) { info in
            Button("Restore & Quit", role: .destructive) {
                restore(info)
            }
            Button("Cancel", role: .cancel) { restoreCandidate = nil }
        } message: { info in
            Text("Your current data will be REPLACED with the backup from \(info.displayName). The app will quit afterward so the store can reopen cleanly.")
        }
        .confirmationDialog(
            "Wipe all data?",
            isPresented: $showWipeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Backup First, Then Wipe", role: .destructive) {
                _ = StoreBackup.backupNow()
                performWipe()
            }
            Button("Wipe Without Backup", role: .destructive) {
                performWipe()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Deletes all exercises, history, streaks, swears, and your profile. This cannot be undone unless you have a backup.")
        }
    }

    // MARK: - Storage info

    private var storageInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage").font(.headline)

            HStack(spacing: 12) {
                statCard(title: "Active store",
                         value: ByteCountFormatter.string(fromByteCount: activeStoreSize, countStyle: .file),
                         subtitle: "your live data")
                statCard(title: "Backups",
                         value: "\(backups.count)",
                         subtitle: ByteCountFormatter.string(fromByteCount: totalBackupSize, countStyle: .file))
            }

            if let base = StoreBackup.discoverStoreBasePath() {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Store location").font(.caption).foregroundStyle(.secondary)
                    Text(base.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold().monospacedDigit())
            Text(subtitle).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions").font(.headline)

            HStack(spacing: 10) {
                Button {
                    runBackupNow()
                } label: {
                    Label("Backup Now", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)

                Button {
                    revealBackups()
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    exportAs()
                } label: {
                    Label("Export JSON…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            Text("Export writes every exercise, record, swear, and milestone as a human-readable JSON file.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Backup list

    private var backupList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Backups").font(.headline)
                Spacer()
                Text("\(backups.count) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if backups.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No backups yet. The app creates one automatically each day you launch it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 8) {
                    ForEach(backups) { info in
                        backupRow(info)
                    }
                }
            }
        }
    }

    private func backupRow(_ info: BackupInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.callout.weight(.medium))
                Text("\(info.displaySize) • \(info.fileCount) file\(info.fileCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                restoreCandidate = info
            } label: {
                Label("Restore", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                deleteBackup(info)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this backup")
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBar: some View {
        if let message = statusMessage {
            HStack(spacing: 8) {
                Image(systemName: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(statusIsError ? .orange : .green)
                Text(message)
                    .font(.callout)
                    .lineLimit(3)
                Spacer()
                if !statusIsError, let url = lastExportURL {
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .controlSize(.small)
                }
                Button {
                    statusMessage = nil
                    lastExportURL = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background((statusIsError ? Color.orange : Color.green).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @State private var lastExportURL: URL?

    // MARK: - Danger zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Danger zone").font(.headline).foregroundStyle(.red)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    showWipeConfirmation = true
                } label: {
                    Label("Wipe All Data", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button(role: .destructive) {
                    showResetPrefsConfirmation = true
                } label: {
                    Label("Reset Preferences", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()
            }

            Text("Wiping deletes every exercise, record, swear, and lock. Reset Preferences restores default settings without touching your data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .confirmationDialog(
            "Reset Preferences?",
            isPresented: $showResetPrefsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Preferences", role: .destructive) {
                resetPreferences()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Restores all settings to their defaults. Your exercises and history are not affected.")
        }
    }

    // MARK: - Operations

    private func refresh() {
        backups = StoreBackup.listBackups()
        activeStoreSize = StoreBackup.activeStoreSize()
        totalBackupSize = StoreBackup.totalBackupSize()
    }

    private func runBackupNow() {
        isBusy = true
        defer { isBusy = false }
        if let folder = StoreBackup.backupNow() {
            flash("Backup created at \(folder.lastPathComponent)", isError: false)
            refresh()
        } else {
            flash("Backup failed. Check the console for details.", isError: true)
        }
    }

    private func restore(_ info: BackupInfo) {
        restoreCandidate = nil
        if StoreBackup.restore(from: info.url) {
            flash("Restore complete. Quitting so the store can reopen…", isError: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSApp.terminate(nil)
            }
        } else {
            flash("Restore failed. Check the console.", isError: true)
        }
    }

    private func deleteBackup(_ info: BackupInfo) {
        if StoreBackup.deleteBackup(info) {
            flash("Deleted backup from \(info.displayName).", isError: false)
            refresh()
        } else {
            flash("Could not delete backup.", isError: true)
        }
    }

    private func performWipe() {
        showWipeConfirmation = false
        if StoreBackup.wipe() {
            flash("Store wiped. Quitting so a fresh store can be created…", isError: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSApp.terminate(nil)
            }
        } else {
            flash("Wipe failed. Some files couldn't be removed.", isError: true)
        }
    }

    private func resetPreferences() {
        showResetPrefsConfirmation = false
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            Preferences.registerDefaults()
            flash("Preferences reset to defaults. Restart the app for all changes to apply.", isError: false)
        }
    }

    private func revealBackups() {
        try? FileManager.default.createDirectory(
            at: StoreBackup.backupRoot,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(StoreBackup.backupRoot)
    }

    // MARK: - Export

    /// Fetches the JSON payload from the current store. Runs on the main
    /// thread, before any modal UI. Returns nil and flashes an error on
    /// failure.
    private func buildExportData() -> Data? {
        // Prefer the AppDelegate's shared container — it's the exact same
        // instance the app itself uses, so no ambiguity about where the
        // store lives or whether it's been initialized.
        let container = DailyForgeAppDelegate.sharedContainer ?? context.container
        do {
            return try StoreBackup.exportAllData(container: container)
        } catch {
            print("⚠️ Export failed: \(error)")
            flash("Export failed: \(error.localizedDescription)", isError: true)
            return nil
        }
    }

    /// Saves straight to ~/Desktop with a timestamped name. Never opens a
    /// panel, so it cannot crash on modal issues.
    private func exportToDesktop() {
        guard let data = buildExportData() else { return }

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
        let url = desktop.appendingPathComponent("DailyForge-export-\(exportTimestamp()).json")

        do {
            try data.write(to: url, options: .atomic)
            lastExportURL = url
            flash("Exported to Desktop: \(url.lastPathComponent)", isError: false)
        } catch {
            flash("Could not write to Desktop: \(error.localizedDescription)", isError: true)
        }
    }

    /// Shows a save panel after the data is already in memory, so SwiftData
    /// isn't touched while the modal loop is running.
    private func exportAs() {
        // 1. Build data first, outside the panel.
        guard let data = buildExportData() else { return }

        // 2. Now show the save panel.
        let panel = NSSavePanel()
        panel.title = "Export DailyForge data"
        panel.nameFieldStringValue = "DailyForge-export-\(exportTimestamp()).json"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if let jsonType = UTType(filenameExtension: "json") {
            panel.allowedContentTypes = [jsonType]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // 3. Write.
        do {
            try data.write(to: url, options: .atomic)
            lastExportURL = url
            flash("Exported: \(url.lastPathComponent)", isError: false)
        } catch {
            flash("Write failed: \(error.localizedDescription)", isError: true)
        }
    }

    private func exportTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f.string(from: Date())
    }

    private func flash(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }
}
