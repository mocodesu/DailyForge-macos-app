import SwiftUI

/// Central mapping of body parts, exercise types, and catalog categories
/// to SF Symbols. Keep all icon choices here so a future change to the
/// visual language is a single-file edit.
enum WorkoutIcons {

    // MARK: - Body parts

    /// Returns an SF Symbol that best represents a body part. Symbols
    /// chosen to exist in SF Symbols 4+ so they render on macOS 13+.
    static func icon(forBodyPart part: String) -> String {
        switch part {
        case "Chest":
            return "figure.strengthtraining.traditional"
        case "Back":
            return "figure.strengthtraining.functional"
        case "Shoulders":
            return "figure.arms.open"
        case "Arms":
            return "dumbbell.fill"
        case "Core":
            return "figure.core.training"
        case "Legs":
            return "figure.walk"
        case "Glutes":
            return "figure.strengthtraining.functional"
        case "Full Body":
            return "figure.highintensity.intervaltraining"
        case "Cardio":
            return "heart.fill"
        default:
            return "figure.strengthtraining.traditional"
        }
    }

    // MARK: - Primary exercise icon

    /// The most representative icon for an exercise. Timed exercises
    /// always show the timer; rep-based exercises show the first body
    /// part's icon.
    static func primaryIcon(for exercise: Exercise) -> String {
        if exercise.exerciseType == .timer {
            return "timer"
        }
        if let first = exercise.bodyParts.first {
            return icon(forBodyPart: first)
        }
        return "figure.strengthtraining.traditional"
    }

    // MARK: - Catalog categories

    static func icon(forCategory category: String) -> String {
        switch category {
        case "Push":
            return "arrow.up.circle.fill"
        case "Pull":
            return "arrow.down.circle.fill"
        case "Legs":
            return "figure.walk"
        case "Core":
            return "figure.core.training"
        case "Cardio":
            return "heart.fill"
        default:
            return "figure.strengthtraining.traditional"
        }
    }

    // MARK: - Exercise type

    static func icon(forType type: ExerciseType) -> String {
        switch type {
        case .reps: return "repeat"
        case .timer: return "timer"
        }
    }
}
