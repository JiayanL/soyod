import Foundation

// MARK: - Enums (String raw, Codable, CaseIterable)

nonisolated enum Sex: String, Codable, CaseIterable, Identifiable, Sendable {
    case male, female
    var id: String { rawValue }
    var title: String { self == .male ? "Male" : "Female" }
}

nonisolated enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary, light, moderate, active, veryActive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Light"
        case .moderate: "Moderate"
        case .active: "Active"
        case .veryActive: "Very active"
        }
    }
    var subtitle: String {
        switch self {
        case .sedentary: "Desk job, little exercise"
        case .light: "1–3 workouts a week"
        case .moderate: "3–5 workouts a week"
        case .active: "6–7 workouts a week"
        case .veryActive: "Training most days, active job"
        }
    }
    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

nonisolated enum Experience: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

nonisolated enum Equipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case gym, home, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .gym: "Full gym"
        case .home: "Home / dumbbells"
        case .none: "Bodyweight only"
        }
    }
}

nonisolated enum DietStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, highProtein, vegetarian, vegan, pescatarian, keto
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "No preference"
        case .highProtein: "High protein"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .pescatarian: "Pescatarian"
        case .keto: "Keto"
        }
    }
}

nonisolated enum UnitSystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case imperial, metric
    var id: String { rawValue }
    var title: String { self == .imperial ? "Imperial" : "Metric" }
}

nonisolated enum CoachTone: String, Codable, CaseIterable, Identifiable, Sendable {
    case direct, encouraging, dataNerd
    var id: String { rawValue }
    var title: String {
        switch self {
        case .direct: "Direct"
        case .encouraging: "Encouraging"
        case .dataNerd: "Data nerd"
        }
    }
}

nonisolated enum MealType: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var symbol: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        case .snack: "takeoutbag.and.cup.and.straw"
        }
    }
}

nonisolated enum MealSource: String, Codable, CaseIterable, Sendable {
    case photo, text, search, quick, coach, sample
}

nonisolated enum WorkoutKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case strength, cardio, sport, mobility, plyometric
    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var symbol: String {
        switch self {
        case .strength: "figure.strengthtraining.traditional"
        case .cardio: "figure.run"
        case .sport: "figure.basketball"
        case .mobility: "figure.flexibility"
        case .plyometric: "arrow.up.to.line"
        }
    }
}

nonisolated enum CardioType: String, Codable, CaseIterable, Identifiable, Sendable {
    case run, ride, swim, row, walk
    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var symbol: String {
        switch self {
        case .run: "figure.run"
        case .ride: "figure.outdoor.cycle"
        case .swim: "figure.pool.swim"
        case .row: "figure.rower"
        case .walk: "figure.walk"
        }
    }
    /// Rough MET value for load/energy estimates.
    var met: Double {
        switch self {
        case .run: 9.8
        case .ride: 7.5
        case .swim: 8.0
        case .row: 7.0
        case .walk: 3.5
        }
    }
}

nonisolated enum WorkoutSource: String, Codable, CaseIterable, Sendable {
    case manual, health, sample
}

nonisolated enum SleepStage: String, Codable, CaseIterable, Sendable {
    case awake, rem, core, deep
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

nonisolated enum SleepSource: String, Codable, CaseIterable, Sendable {
    case manual, health, sample
}

nonisolated enum MessageRole: String, Codable, CaseIterable, Sendable {
    case user, coach
}

nonisolated enum MemoryKind: String, Codable, CaseIterable, Sendable {
    case fact, preference, task
    var title: String {
        switch self {
        case .fact: "Facts"
        case .preference: "Preferences"
        case .task: "Tasks"
        }
    }
}

nonisolated enum Pillar: String, Codable, CaseIterable, Identifiable, Sendable {
    case goal, fuel, train, sleep, recovery
    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var symbol: String {
        switch self {
        case .goal: "scope"
        case .fuel: "fork.knife"
        case .train: "figure.strengthtraining.traditional"
        case .sleep: "moon.stars.fill"
        case .recovery: "heart.fill"
        }
    }
}

// MARK: - Goals

nonisolated enum MetricDimension: String, Codable, Sendable {
    case length, mass, time, custom
}

nonisolated enum GoalMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case verticalJump, waist, hipThrust1RM, bodyWeight
    case squat1RM, bench1RM, deadlift1RM
    case fiveK, tenK, custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .verticalJump: "Vertical jump"
        case .waist: "Waist"
        case .hipThrust1RM: "Hip thrust 1RM"
        case .bodyWeight: "Body weight"
        case .squat1RM: "Squat 1RM"
        case .bench1RM: "Bench 1RM"
        case .deadlift1RM: "Deadlift 1RM"
        case .fiveK: "5K time"
        case .tenK: "10K time"
        case .custom: "Custom"
        }
    }
    var dimension: MetricDimension {
        switch self {
        case .verticalJump, .waist: .length
        case .hipThrust1RM, .bodyWeight, .squat1RM, .bench1RM, .deadlift1RM: .mass
        case .fiveK, .tenK: .time
        case .custom: .custom
        }
    }
    /// True when a lower value is better (weight, waist, run times).
    var lowerIsBetter: Bool {
        switch self {
        case .waist, .bodyWeight, .fiveK, .tenK: true
        default: false
        }
    }
}

nonisolated enum GoalKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case vertical, waist, glutes, fatLoss, muscle, strength, run, custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .vertical: "Jump higher"
        case .waist: "Slim waist"
        case .glutes: "Build glutes"
        case .fatLoss: "Lose fat"
        case .muscle: "Build muscle"
        case .strength: "Get stronger"
        case .run: "Run faster"
        case .custom: "Custom goal"
        }
    }
    var subtitle: String {
        switch self {
        case .vertical: "Add inches to your vertical"
        case .waist: "Trim inches off your waist"
        case .glutes: "Grow your glutes and hip thrust"
        case .fatLoss: "Drop body fat, keep muscle"
        case .muscle: "Add lean mass"
        case .strength: "Raise your big-3 lifts"
        case .run: "Run a faster 5K"
        case .custom: "Name any outcome"
        }
    }
    var symbol: String {
        switch self {
        case .vertical: "arrow.up.to.line"
        case .waist: "ruler"
        case .glutes: "figure.strengthtraining.functional"
        case .fatLoss: "flame"
        case .muscle: "figure.strengthtraining.traditional"
        case .strength: "dumbbell"
        case .run: "figure.run"
        case .custom: "scope"
        }
    }
    var defaultMetric: GoalMetric {
        switch self {
        case .vertical: .verticalJump
        case .waist: .waist
        case .glutes: .hipThrust1RM
        case .fatLoss: .bodyWeight
        case .muscle: .bodyWeight
        case .strength: .deadlift1RM
        case .run: .fiveK
        case .custom: .custom
        }
    }
    var suggestedWeeks: Int {
        switch self {
        case .vertical: 16
        case .waist: 20
        case .glutes: 16
        case .fatLoss: 16
        case .muscle: 20
        case .strength: 16
        case .run: 12
        case .custom: 12
        }
    }
    /// Imperial-friendly (baseline, target) defaults in canonical units
    /// (cm / kg / seconds).
    var defaultBaselineTarget: (baseline: Double, target: Double) {
        switch self {
        case .vertical: (62.2, 76.2)          // 24.5" -> 30"
        case .waist: (86.4, 76.2)             // 34" -> 30"
        case .glutes: (61.2, 79.4)            // 135 lb -> 175 lb
        case .fatLoss: (90.7, 81.6)           // 200 lb -> 180 lb
        case .muscle: (72.6, 79.4)            // 160 lb -> 175 lb
        case .strength: (140.6, 183.7)        // 310 lb -> 405 lb
        case .run: (1530, 1200)               // 25:30 -> 20:00
        case .custom: (0, 1)
        }
    }
}
