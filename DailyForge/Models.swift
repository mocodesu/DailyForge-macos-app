import Foundation
import SwiftData

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case reps
    case timer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reps: return "Repetitions"
        case .timer: return "Timed"
        }
    }

    var icon: String {
        switch self {
        case .reps: return "repeat"
        case .timer: return "timer"
        }
    }
}

@Model
final class Exercise {
    var id: UUID
    var name: String
    var bodyParts: [String]
    var exerciseTypeRaw: String
    var reps: Int
    var sets: Int
    var durationSeconds: Int
    var sessionDurationSeconds: Int
    var isDaily: Bool
    var notes: String
    var createdAt: Date
    var sortIndex: Int

    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: exerciseTypeRaw) ?? .reps }
        set { exerciseTypeRaw = newValue.rawValue }
    }

    init(
        name: String,
        bodyParts: [String],
        exerciseType: ExerciseType,
        reps: Int = 0,
        sets: Int,
        durationSeconds: Int = 0,
        sessionDurationSeconds: Int,
        isDaily: Bool = true,
        notes: String,
        sortIndex: Int
    ) {
        self.id = UUID()
        self.name = name
        self.bodyParts = bodyParts
        self.exerciseTypeRaw = exerciseType.rawValue
        self.reps = reps
        self.sets = sets
        self.durationSeconds = durationSeconds
        self.sessionDurationSeconds = sessionDurationSeconds
        self.isDaily = isDaily
        self.notes = notes
        self.createdAt = Date()
        self.sortIndex = sortIndex
    }
}

@Model
final class CompletionRecord {
    var id: UUID
    var exerciseID: UUID
    var dayKey: String
    /// When the user tapped "Start Workout". Nil for records created via
    /// the debug skip button or any future migration from older stores.
    var startedAt: Date?
    var completedAt: Date

    init(exerciseID: UUID, dayKey: String, startedAt: Date? = nil, completedAt: Date = Date()) {
        self.id = UUID()
        self.exerciseID = exerciseID
        self.dayKey = dayKey
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

@Model
final class DayLock {
    var id: UUID
    var dayKey: String
    var lockedAt: Date

    init(dayKey: String) {
        self.id = UUID()
        self.dayKey = dayKey
        self.lockedAt = Date()
    }
}

@Model
final class DailySwear {
    var id: UUID
    var dayKey: String
    var swornAt: Date
    var transcript: String
    var matchedPhrase: String

    init(dayKey: String, transcript: String, matchedPhrase: String) {
        self.id = UUID()
        self.dayKey = dayKey
        self.swornAt = Date()
        self.transcript = transcript
        self.matchedPhrase = matchedPhrase
    }
}

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    /// Age in years. Defaults to 0 for records created before this field
    /// existed; the UI treats 0 as "not set".
    var age: Int = 0
    var startDate: Date
    var initialWeightKg: Double
    var goalWeightKg: Double
    var initialHeightCm: Double
    @Attribute(.externalStorage) var initialFrontPhoto: Data?
    @Attribute(.externalStorage) var initialSidePhoto: Data?

    init(
        displayName: String,
        age: Int = 0,
        initialWeightKg: Double,
        goalWeightKg: Double,
        initialHeightCm: Double
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.age = age
        self.startDate = Date()
        self.initialWeightKg = initialWeightKg
        self.goalWeightKg = goalWeightKg
        self.initialHeightCm = initialHeightCm
    }
}

@Model
final class Milestone {
    var id: UUID
    var day: Int
    var unlockedAt: Date
    var completedAt: Date?
    var currentWeightKg: Double?
    @Attribute(.externalStorage) var currentFrontPhoto: Data?
    @Attribute(.externalStorage) var currentSidePhoto: Data?
    var aiSummary: String?
    var userNotes: String

    init(day: Int) {
        self.id = UUID()
        self.day = day
        self.unlockedAt = Date()
        self.userNotes = ""
    }
}

@Model
final class StreakFreeze {
    var id: UUID
    /// Calendar day key (`yyyy-MM-dd`) of the day that was frozen.
    var dayKey: String
    /// When the freeze token was spent.
    var usedAt: Date
    /// Optional user note explaining why they froze that day.
    var note: String

    init(dayKey: String, note: String = "") {
        self.id = UUID()
        self.dayKey = dayKey
        self.usedAt = Date()
        self.note = note
    }
}
