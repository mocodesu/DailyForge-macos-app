import Foundation
import SwiftData

// MARK: - Backup Info

struct BackupInfo: Identifiable, Hashable {
    let url: URL
    let date: Date
    let sizeBytes: Int64
    let fileCount: Int

    var id: URL { url }

    var displayName: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

// MARK: - Store Backup

enum StoreBackup {

    /// Discovers where the SwiftData store actually lives. Handles both the
    /// non-sandboxed location and the sandbox container, and returns nil if
    /// nothing exists yet (fresh install).
    static func discoverStoreBasePath() -> URL? {
        let fm = FileManager.default

        // Non-sandboxed (typical for a personal build)
        let nonSandboxed = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/default.store")
        if fm.fileExists(atPath: nonSandboxed.path) {
            return nonSandboxed
        }

        // Sandboxed container, if the app is ever sandboxed
        if let bundleID = Bundle.main.bundleIdentifier {
            let sandboxed = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Containers")
                .appendingPathComponent(bundleID)
                .appendingPathComponent("Data/Library/Application Support/default.store")
            if fm.fileExists(atPath: sandboxed.path) {
                return sandboxed
            }
        }

        // Not found — return the standard path anyway so future writes go
        // to the right place.
        return nonSandboxed
    }

    /// URLs for the three files that make up the store.
    static func storeFiles() -> [URL] {
        guard let base = discoverStoreBasePath() else { return [] }
        let basePath = base.path
        return ["", "-shm", "-wal"].map { URL(fileURLWithPath: basePath + $0) }
    }

    static var backupRoot: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/DailyForge/backups")
    }

    // MARK: - Auto-backup

    /// Copies the current store into a dated folder if no backup exists
    /// for today. Called before the ModelContainer opens so files on disk
    /// are quiescent.
    static func autoBackupIfNeeded() {
        let fm = FileManager.default
        guard let base = discoverStoreBasePath(), fm.fileExists(atPath: base.path) else { return }

        let dayKey = currentDayKey()
        let dayFolder = backupRoot.appendingPathComponent(dayKey)
        guard !fm.fileExists(atPath: dayFolder.path) else { return }

        do {
            try fm.createDirectory(at: dayFolder, withIntermediateDirectories: true)
            for source in storeFiles() where fm.fileExists(atPath: source.path) {
                let dest = dayFolder.appendingPathComponent(source.lastPathComponent)
                try fm.copyItem(at: source, to: dest)
            }
            print("💾 Auto-backup created at \(dayFolder.path)")
            pruneOldBackups(keeping: 14)
        } catch {
            print("⚠️ Auto-backup failed: \(error)")
        }
    }

    // MARK: - Manual operations

    /// On-demand backup with a timestamp. Returns the folder URL on success.
    static func backupNow() -> URL? {
        let fm = FileManager.default
        guard let base = discoverStoreBasePath(), fm.fileExists(atPath: base.path) else { return nil }

        let stamp = timestampKey()
        let folder = backupRoot.appendingPathComponent(stamp)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for source in storeFiles() where fm.fileExists(atPath: source.path) {
                let dest = folder.appendingPathComponent(source.lastPathComponent)
                try fm.copyItem(at: source, to: dest)
            }
            pruneOldBackups(keeping: 14)
            return folder
        } catch {
            print("⚠️ Manual backup failed: \(error)")
            return nil
        }
    }

    /// Returns backup folders newest first with size and date metadata.
    static func listBackups() -> [BackupInfo] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { url -> BackupInfo? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            let files = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            let size = files.reduce(Int64(0)) { partial, fileURL in
                let bytes = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return partial + Int64(bytes)
            }
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return BackupInfo(url: url, date: date, sizeBytes: size, fileCount: files.count)
        }
        .sorted { $0.date > $1.date }
    }

    /// Restores store files from the given backup folder. Overwrites whatever
    /// is currently on disk. Caller must ensure the app is not holding the
    /// store open, or should quit afterward.
    static func restore(from backupFolder: URL) -> Bool {
        let fm = FileManager.default
        do {
            for source in storeFiles() where fm.fileExists(atPath: source.path) {
                try fm.removeItem(at: source)
            }
            guard let base = discoverStoreBasePath() else { return false }
            let destDirectory = base.deletingLastPathComponent()
            let contents = try fm.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: nil)
            for file in contents {
                let dest = destDirectory.appendingPathComponent(file.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: file, to: dest)
            }
            print("✅ Restored from \(backupFolder.path)")
            return true
        } catch {
            print("⚠️ Restore failed: \(error)")
            return false
        }
    }

    /// Deletes the current store. No backup is made.
    static func wipe() -> Bool {
        let fm = FileManager.default
        var allOk = true
        for source in storeFiles() where fm.fileExists(atPath: source.path) {
            do {
                try fm.removeItem(at: source)
            } catch {
                print("⚠️ Could not remove \(source.lastPathComponent): \(error)")
                allOk = false
            }
        }
        return allOk
    }

    /// Deletes a specific backup folder.
    static func deleteBackup(_ info: BackupInfo) -> Bool {
        do {
            try FileManager.default.removeItem(at: info.url)
            return true
        } catch {
            print("⚠️ Could not delete backup: \(error)")
            return false
        }
    }

    /// Combined size of all backup folders.
    static func totalBackupSize() -> Int64 {
        listBackups().reduce(0) { $0 + $1.sizeBytes }
    }

    /// Size of the active store on disk.
    static func activeStoreSize() -> Int64 {
        storeFiles().reduce(0) { partial, url in
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return partial + Int64(bytes)
        }
    }

    // MARK: - Export

    /// Dumps every model into a single JSON file for archiving.
    static func exportAllData(container: ModelContainer) throws -> Data {
        let context = ModelContext(container)

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let records = (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? []
        let locks = (try? context.fetch(FetchDescriptor<DayLock>())) ?? []
        let swears = (try? context.fetch(FetchDescriptor<DailySwear>())) ?? []
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let milestones = (try? context.fetch(FetchDescriptor<Milestone>())) ?? []

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let export = ExportBundle(
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            exercises: exercises.map(ExerciseSnapshot.init),
            records: records.map(RecordSnapshot.init),
            locks: locks.map { LockSnapshot(dayKey: $0.dayKey, lockedAt: $0.lockedAt) },
            swears: swears.map { SwearSnapshot(dayKey: $0.dayKey, swornAt: $0.swornAt, transcript: $0.transcript, matchedPhrase: $0.matchedPhrase) },
            profiles: profiles.map(ProfileSnapshot.init),
            milestones: milestones.map(MilestoneSnapshot.init)
        )
        return try encoder.encode(export)
    }

    // MARK: - Helpers

    private static func currentDayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    private static func timestampKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        f.timeZone = .current
        return f.string(from: Date())
    }

    private static func pruneOldBackups(keeping: Int) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let sorted = contents.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return aDate > bDate
        }

        for old in sorted.dropFirst(keeping) {
            try? fm.removeItem(at: old)
            print("🗑️ Pruned old backup: \(old.lastPathComponent)")
        }
    }
}

// MARK: - Export snapshots

private struct ExportBundle: Codable {
    let exportedAt: Date
    let appVersion: String
    let exercises: [ExerciseSnapshot]
    let records: [RecordSnapshot]
    let locks: [LockSnapshot]
    let swears: [SwearSnapshot]
    let profiles: [ProfileSnapshot]
    let milestones: [MilestoneSnapshot]
}

private struct ExerciseSnapshot: Codable {
    let id: UUID
    let name: String
    let bodyParts: [String]
    let exerciseTypeRaw: String
    let reps: Int
    let sets: Int
    let durationSeconds: Int
    let sessionDurationSeconds: Int
    let isDaily: Bool
    let notes: String
    let createdAt: Date
    let sortIndex: Int

    init(_ e: Exercise) {
        id = e.id
        name = e.name
        bodyParts = e.bodyParts
        exerciseTypeRaw = e.exerciseTypeRaw
        reps = e.reps
        sets = e.sets
        durationSeconds = e.durationSeconds
        sessionDurationSeconds = e.sessionDurationSeconds
        isDaily = e.isDaily
        notes = e.notes
        createdAt = e.createdAt
        sortIndex = e.sortIndex
    }
}

private struct RecordSnapshot: Codable {
    let id: UUID
    let exerciseID: UUID
    let dayKey: String
    let startedAt: Date?
    let completedAt: Date

    init(_ r: CompletionRecord) {
        id = r.id
        exerciseID = r.exerciseID
        dayKey = r.dayKey
        startedAt = r.startedAt
        completedAt = r.completedAt
    }
}

private struct LockSnapshot: Codable {
    let dayKey: String
    let lockedAt: Date
}

private struct SwearSnapshot: Codable {
    let dayKey: String
    let swornAt: Date
    let transcript: String
    let matchedPhrase: String
}

private struct ProfileSnapshot: Codable {
    let id: UUID
    let displayName: String
    let startDate: Date
    let initialWeightKg: Double
    let goalWeightKg: Double
    let initialHeightCm: Double

    init(_ p: UserProfile) {
        id = p.id
        displayName = p.displayName
        startDate = p.startDate
        initialWeightKg = p.initialWeightKg
        goalWeightKg = p.goalWeightKg
        initialHeightCm = p.initialHeightCm
    }
}

private struct MilestoneSnapshot: Codable {
    let id: UUID
    let day: Int
    let unlockedAt: Date
    let completedAt: Date?
    let currentWeightKg: Double?
    let aiSummary: String?
    let userNotes: String

    init(_ m: Milestone) {
        id = m.id
        day = m.day
        unlockedAt = m.unlockedAt
        completedAt = m.completedAt
        currentWeightKg = m.currentWeightKg
        aiSummary = m.aiSummary
        userNotes = m.userNotes
    }
}
