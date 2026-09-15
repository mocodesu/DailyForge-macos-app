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
    var isDaily: Bool                // ← new: repeat every day?
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
    var completedAt: Date

    init(exerciseID: UUID, dayKey: String) {
        self.id = UUID()
        self.exerciseID = exerciseID
        self.dayKey = dayKey
        self.completedAt = Date()
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
final class UserProfile {
    var id: UUID
    var displayName: String
    var startDate: Date
    var initialWeightKg: Double
    var goalWeightKg: Double
    @Attribute(.externalStorage) var initialFrontPhoto: Data?
    @Attribute(.externalStorage) var initialSidePhoto: Data?

    init(displayName: String, initialWeightKg: Double, goalWeightKg: Double) {
        self.id = UUID()
        self.displayName = displayName
        self.startDate = Date()
        self.initialWeightKg = initialWeightKg
        self.goalWeightKg = goalWeightKg
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
