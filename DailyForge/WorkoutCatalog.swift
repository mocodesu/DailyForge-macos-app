import Foundation

// MARK: - Catalog Model

struct CatalogExercise: Identifiable, Hashable {
    let name: String
    let category: String
    let bodyParts: [String]
    let exerciseType: ExerciseType
    let sets: Int
    let reps: Int           // used when exerciseType == .reps
    let perSetSeconds: Int  // used when exerciseType == .timer
    let sessionSeconds: Int
    let notes: String

    var id: String { name }
}

// MARK: - Catalog

enum WorkoutCatalog {

    static let categories: [String] = [
        "Push", "Pull", "Legs", "Core", "Cardio"
    ]

    static let all: [CatalogExercise] = [

        // MARK: Push

        CatalogExercise(
            name: "Push-ups", category: "Push",
            bodyParts: ["Chest", "Arms"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Elbows tucked at 45°. Full range of motion — chest to floor."
        ),
        CatalogExercise(
            name: "Knee Push-ups", category: "Push",
            bodyParts: ["Chest", "Arms"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Easier variation. Same form cues — straight line from head to knees."
        ),
        CatalogExercise(
            name: "Diamond Push-ups", category: "Push",
            bodyParts: ["Chest", "Arms"],
            exerciseType: .reps, sets: 3, reps: 10, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Hands together under chest. Triceps focus."
        ),
        CatalogExercise(
            name: "Wall Push-ups", category: "Push",
            bodyParts: ["Chest", "Arms"],
            exerciseType: .reps, sets: 3, reps: 15, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Beginner variation. Lean into the wall, push back."
        ),
        CatalogExercise(
            name: "Tricep Dips", category: "Push",
            bodyParts: ["Arms"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Use a stable chair or bench. Elbows point straight back."
        ),
        CatalogExercise(
            name: "Pike Push-ups", category: "Push",
            bodyParts: ["Shoulders", "Arms"],
            exerciseType: .reps, sets: 3, reps: 10, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Hips high, head between hands. Shoulder press pattern."
        ),

        // MARK: Pull

        CatalogExercise(
            name: "Superman", category: "Pull",
            bodyParts: ["Back", "Core"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Lift chest and legs off the floor. Squeeze glutes at the top."
        ),
        CatalogExercise(
            name: "Reverse Snow Angels", category: "Pull",
            bodyParts: ["Back", "Shoulders"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Lie face down. Sweep arms from hips to overhead and back."
        ),
        CatalogExercise(
            name: "Doorway Rows", category: "Pull",
            bodyParts: ["Back", "Arms"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Grip the doorframe. Lean back and pull chest to frame."
        ),

        // MARK: Legs

        CatalogExercise(
            name: "Squats", category: "Legs",
            bodyParts: ["Legs", "Glutes"],
            exerciseType: .reps, sets: 3, reps: 15, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Knees track over toes. Chest up. Sit back and down."
        ),
        CatalogExercise(
            name: "Lunges", category: "Legs",
            bodyParts: ["Legs", "Glutes"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Alternate legs. Back knee close to floor. Chest tall."
        ),
        CatalogExercise(
            name: "Reverse Lunges", category: "Legs",
            bodyParts: ["Legs", "Glutes"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Step back instead of forward. Easier on the knees."
        ),
        CatalogExercise(
            name: "Glute Bridges", category: "Legs",
            bodyParts: ["Glutes", "Legs"],
            exerciseType: .reps, sets: 3, reps: 15, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Feet flat, hips drive up. Squeeze glutes hard at the top."
        ),
        CatalogExercise(
            name: "Calf Raises", category: "Legs",
            bodyParts: ["Legs"],
            exerciseType: .reps, sets: 3, reps: 20, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Full range. Pause at the top. Slow on the way down."
        ),
        CatalogExercise(
            name: "Wall Sit", category: "Legs",
            bodyParts: ["Legs", "Glutes"],
            exerciseType: .timer, sets: 3, reps: 0, perSetSeconds: 45,
            sessionSeconds: 90,
            notes: "Thighs parallel to floor. Back flat against the wall."
        ),
        CatalogExercise(
            name: "Jump Squats", category: "Legs",
            bodyParts: ["Legs", "Cardio"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 90,
            notes: "Explode up. Land soft through the balls of your feet."
        ),

        // MARK: Core

        CatalogExercise(
            name: "Plank", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .timer, sets: 3, reps: 0, perSetSeconds: 30,
            sessionSeconds: 90,
            notes: "Straight line from head to heels. Don't let hips sag."
        ),
        CatalogExercise(
            name: "Side Plank", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .timer, sets: 3, reps: 0, perSetSeconds: 30,
            sessionSeconds: 90,
            notes: "Stack hips. Lift bottom ribs. Switch sides between sets."
        ),
        CatalogExercise(
            name: "Hollow Body Hold", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .timer, sets: 3, reps: 0, perSetSeconds: 30,
            sessionSeconds: 90,
            notes: "Lower back pressed into floor. Arms and legs low."
        ),
        CatalogExercise(
            name: "Crunches", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .reps, sets: 3, reps: 15, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Hands behind head — don't pull the neck. Curl the ribs."
        ),
        CatalogExercise(
            name: "Sit-ups", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .reps, sets: 3, reps: 15, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Feet anchored. Full range — chest to knees."
        ),
        CatalogExercise(
            name: "Bicycle Crunches", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .reps, sets: 3, reps: 20, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Slow and controlled. Elbow to opposite knee."
        ),
        CatalogExercise(
            name: "Russian Twists", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .reps, sets: 3, reps: 20, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Rotate the torso, not just the arms. Chest up."
        ),
        CatalogExercise(
            name: "Leg Raises", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .reps, sets: 3, reps: 12, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Keep lower back pressed down. Lower slowly."
        ),
        CatalogExercise(
            name: "Dead Bug", category: "Core",
            bodyParts: ["Core"],
            exerciseType: .reps, sets: 3, reps: 10, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Opposite arm and leg. Slow. Keep back flat."
        ),
        CatalogExercise(
            name: "Bird Dog", category: "Core",
            bodyParts: ["Core", "Back"],
            exerciseType: .reps, sets: 3, reps: 10, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Opposite arm and leg. Hold 2 seconds at full extension."
        ),
        CatalogExercise(
            name: "Mountain Climbers", category: "Core",
            bodyParts: ["Core", "Cardio"],
            exerciseType: .reps, sets: 3, reps: 20, perSetSeconds: 0,
            sessionSeconds: 60,
            notes: "Fast knees to chest. Hips stay low and level."
        ),

        // MARK: Cardio

        CatalogExercise(
            name: "Jumping Jacks", category: "Cardio",
            bodyParts: ["Cardio", "Full Body"],
            exerciseType: .reps, sets: 3, reps: 30, perSetSeconds: 0,
            sessionSeconds: 90,
            notes: "Full range. Steady pace. Land soft."
        ),
        CatalogExercise(
            name: "High Knees", category: "Cardio",
            bodyParts: ["Cardio", "Legs"],
            exerciseType: .reps, sets: 3, reps: 30, perSetSeconds: 0,
            sessionSeconds: 90,
            notes: "Knees to hip height. Fast. On the balls of your feet."
        ),
        CatalogExercise(
            name: "Butt Kicks", category: "Cardio",
            bodyParts: ["Cardio", "Legs"],
            exerciseType: .reps, sets: 3, reps: 30, perSetSeconds: 0,
            sessionSeconds: 90,
            notes: "Heels to glutes. Fast. Light on feet."
        ),
        CatalogExercise(
            name: "Burpees", category: "Cardio",
            bodyParts: ["Full Body", "Cardio"],
            exerciseType: .reps, sets: 3, reps: 10, perSetSeconds: 0,
            sessionSeconds: 120,
            notes: "Squat, plank, push-up, jump. Full commitment on every rep."
        ),
        CatalogExercise(
            name: "Jump Rope", category: "Cardio",
            bodyParts: ["Cardio"],
            exerciseType: .timer, sets: 3, reps: 0, perSetSeconds: 60,
            sessionSeconds: 180,
            notes: "Light on your feet. Wrists do the work, not the arms."
        ),
        CatalogExercise(
            name: "Skater Jumps", category: "Cardio",
            bodyParts: ["Cardio", "Legs"],
            exerciseType: .reps, sets: 3, reps: 20, perSetSeconds: 0,
            sessionSeconds: 90,
            notes: "Side to side. Land soft. Swing arms for balance."
        )
    ]

    static func byCategory(_ category: String) -> [CatalogExercise] {
        all.filter { $0.category == category }
    }

    static func item(named name: String) -> CatalogExercise? {
        all.first { $0.name == name }
    }
}
