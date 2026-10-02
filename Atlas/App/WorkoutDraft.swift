import Foundation

/// Input for AppState.saveWorkout (logger output).
nonisolated struct WorkoutDraft {
    var kind: WorkoutKind
    var title: String
    var start: Date
    var durationSec: Int
    var exercises: [ExerciseLog] = []
    var cardioType: CardioType? = nil
    var distanceM: Double? = nil
    var avgHR: Int? = nil
    var rpe: Double? = nil
    var sport: String? = nil
}

nonisolated struct PRRecord: Hashable, Sendable {
    var exerciseName: String
    var weightKg: Double
    var reps: Int
    var e1RM: Double
}

nonisolated struct WorkoutSaveResult {
    var workout: Workout
    var prs: [PRRecord]
}
