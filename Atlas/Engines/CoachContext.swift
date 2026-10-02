import Foundation

// MARK: - Snapshots & context value types
// Pure Sendable structs produced by the engines/ContextBuilder and consumed by
// the coach, Game Plan engine, and views.

nonisolated struct CalendarEventInfo: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var location: String?
    var isSynthetic: Bool = false
}

nonisolated struct GoalSnapshot: Codable, Hashable, Sendable {
    var kind: GoalKind
    var title: String
    var metric: GoalMetric
    var customUnit: String?
    var baseline: Double
    var current: Double
    var target: Double
    var startDate: Date
    var targetDate: Date
    var daysLeft: Int
    var projection: Projection
}

nonisolated enum ProjectionStatus: String, Codable, Sendable {
    case ahead, onTrack, behind, insufficientData, reached

    var title: String {
        switch self {
        case .ahead: "Ahead"
        case .onTrack: "On track"
        case .behind: "Behind"
        case .insufficientData: "Not enough data"
        case .reached: "Reached"
        }
    }
}

nonisolated struct Projection: Codable, Hashable, Sendable {
    var current: Double
    var slopePerDay: Double
    var projectedDate: Date?
    var status: ProjectionStatus
    var daysVsTarget: Int = 0     // positive = early
    var progress: Double = 0      // 0…1
}

nonisolated struct MealSnapshot: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var title: String
    var mealType: MealType
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var hasPhoto: Bool
}

nonisolated struct WorkoutSnapshot: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var kind: WorkoutKind
    var title: String
    var durationMin: Int
    var load: Double
    var sport: String?
}

nonisolated struct SleepSummary: Codable, Hashable, Sendable {
    var start: Date
    var end: Date
    var asleepMin: Int
    var inBedMin: Int
    var efficiency: Double       // 0…1
    var awakeMin: Int
    var remMin: Int
    var coreMin: Int
    var deepMin: Int
    var hrvMs: Double?
    var restingHR: Double?
    var score: Int
}

nonisolated struct TrainingLoad: Codable, Hashable, Sendable {
    var acute7: Double
    var chronic28: Double
    var ratio: Double            // acute / chronic (chronic=avg per week)
    var status: String           // "Optimal" / "High" / "Low"
}

nonisolated struct EatingWindowState: Codable, Hashable, Sendable {
    var opens: Date
    var closes: Date
    var isOpen: Bool
    var nextChange: Date
    var minutesToNextChange: Int
}

nonisolated struct MemorySnapshot: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: MemoryKind
    var text: String
    var dueDate: Date?
}

nonisolated struct PlanSnapshotValue: Codable, Hashable, Sendable {
    var kcalTarget: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var sleepTargetMin: Int
    var weeklySplit: [PlannedSession]
    var rationale: String

    static let empty = PlanSnapshotValue(kcalTarget: 0, proteinG: 0, carbsG: 0,
                                         fatG: 0, sleepTargetMin: 480,
                                         weeklySplit: [], rationale: "")
}

nonisolated enum ScoreBand: String, Codable, Sendable {
    case low, mid, high
}

/// Everything the coach, Game Plan engine, and views need for "today".
nonisolated struct CoachContext: Sendable {
    var now: Date
    var userName: String = ""
    var tone: CoachTone = .direct
    var units: UnitSystem = .imperial

    var goal: GoalSnapshot?
    var targets: MacroTargets = MacroTargets(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)
    var eaten: MacroTotals = MacroTotals()
    var remaining: MacroTotals = MacroTotals()
    var mealsToday: [MealSnapshot] = []
    var eatingWindow: EatingWindowState?

    var lastSleep: SleepSummary?
    var recentSleep: [SleepSummary] = []   // last 7 nights, oldest first
    var sleepNeedMin: Int = 480
    var recoveryScore: Int?
    var hrvDeltaPct: Double?
    var rhrDelta: Double?
    var hrvBaseline: Double?
    var rhrBaseline: Double?

    var todaySession: PlannedSession?
    var completedToday: [WorkoutSnapshot] = []
    var recentWorkouts: [WorkoutSnapshot] = []   // last 14 days
    var load: TrainingLoad = TrainingLoad(acute7: 0, chronic28: 0, ratio: 0, status: "Low")

    var weekSplit: [PlannedSession] = []
    var events: [CalendarEventInfo] = []
    var tomorrowFirstEvent: CalendarEventInfo?
    var recommendedBedtime: Date = Date()

    var memories: [MemorySnapshot] = []
    var steps: Int?
    var plan: PlanSnapshotValue = .empty
}
