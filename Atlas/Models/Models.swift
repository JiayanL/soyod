import Foundation
import SwiftData

// MARK: - SwiftData models
// Enums are stored as raw String + computed accessor, and Codable arrays as
// JSON Data + computed accessor, to avoid SwiftData composite-attribute bugs.

@Model
final class UserProfile {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var sexRaw: String = Sex.male.rawValue
    var birthYear: Int = 1998
    var heightCm: Double = 178
    var weightKg: Double = 80
    var activityLevelRaw: String = ActivityLevel.moderate.rawValue
    var experienceRaw: String = Experience.intermediate.rawValue
    var trainingDaysPerWeek: Int = 4
    var equipmentRaw: String = Equipment.gym.rawValue
    var dietStyleRaw: String = DietStyle.none.rawValue
    var allergiesData: Data = Data()
    var fastingStartMinutes: Int?
    var fastingEndMinutes: Int?
    var unitSystemRaw: String = UnitSystem.imperial.rawValue
    var coachToneRaw: String = CoachTone.direct.rawValue
    var createdAt: Date = Date()
    var onboardingComplete: Bool = false
    var isSampleData: Bool = false

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }
    var experience: Experience {
        get { Experience(rawValue: experienceRaw) ?? .intermediate }
        set { experienceRaw = newValue.rawValue }
    }
    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .gym }
        set { equipmentRaw = newValue.rawValue }
    }
    var dietStyle: DietStyle {
        get { DietStyle(rawValue: dietStyleRaw) ?? .none }
        set { dietStyleRaw = newValue.rawValue }
    }
    var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .imperial }
        set { unitSystemRaw = newValue.rawValue }
    }
    var coachTone: CoachTone {
        get { CoachTone(rawValue: coachToneRaw) ?? .direct }
        set { coachToneRaw = newValue.rawValue }
    }
    var allergies: [String] {
        get { (try? JSONDecoder().decode([String].self, from: allergiesData)) ?? [] }
        set { allergiesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var age: Int {
        Calendar.current.component(.year, from: AppClock.now) - birthYear
    }

    /// Eating window open/close as minutes after midnight, if fasting is set.
    var eatingWindow: (open: Int, close: Int)? {
        guard let s = fastingStartMinutes, let e = fastingEndMinutes else { return nil }
        return (s, e)
    }
}

@Model
final class Goal {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var kindRaw: String = GoalKind.vertical.rawValue
    var title: String = ""
    var metricRaw: String = GoalMetric.verticalJump.rawValue
    var customUnit: String?
    var baseline: Double = 0
    var target: Double = 0
    var startDate: Date = Date()
    var targetDate: Date = Date()
    var isActive: Bool = true

    var kind: GoalKind {
        get { GoalKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }
    var metric: GoalMetric {
        get { GoalMetric(rawValue: metricRaw) ?? .custom }
        set { metricRaw = newValue.rawValue }
    }
    var isDecreasing: Bool { target < baseline }
}

@Model
final class Measurement {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var metricRaw: String = GoalMetric.custom.rawValue
    var value: Double = 0     // canonical
    var note: String?

    var metric: GoalMetric {
        get { GoalMetric(rawValue: metricRaw) ?? .custom }
        set { metricRaw = newValue.rawValue }
    }
}

@Model
final class PlanSnapshot {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var createdAt: Date = Date()
    var kcalTarget: Int = 0
    var proteinG: Int = 0
    var carbsG: Int = 0
    var fatG: Int = 0
    var sleepTargetMin: Int = 480
    var weeklySplitData: Data = Data()
    var rationale: String = ""

    var weeklySplit: [PlannedSession] {
        get { (try? JSONDecoder().decode([PlannedSession].self, from: weeklySplitData)) ?? [] }
        set { weeklySplitData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

@Model
final class MealEntry {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var mealTypeRaw: String = MealType.lunch.rawValue
    var title: String = ""
    @Attribute(.externalStorage) var photo: Data?
    var itemsData: Data = Data()
    var sourceRaw: String = MealSource.text.rawValue

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .lunch }
        set { mealTypeRaw = newValue.rawValue }
    }
    var source: MealSource {
        get { MealSource(rawValue: sourceRaw) ?? .text }
        set { sourceRaw = newValue.rawValue }
    }
    var items: [FoodItem] {
        get { (try? JSONDecoder().decode([FoodItem].self, from: itemsData)) ?? [] }
        set { itemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var totalKcal: Double { items.reduce(0) { $0 + $1.kcal } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fat } }
}

@Model
final class Workout {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = WorkoutKind.strength.rawValue
    var title: String = ""
    var durationSec: Int = 0
    var distanceM: Double?
    var avgHR: Int?
    var rpe: Double?
    var load: Double = 0
    var exercisesData: Data = Data()
    var sourceRaw: String = WorkoutSource.manual.rawValue
    var sport: String?
    var healthKitUUID: String?

    var kind: WorkoutKind {
        get { WorkoutKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }
    var source: WorkoutSource {
        get { WorkoutSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
    var exercises: [ExerciseLog] {
        get { (try? JSONDecoder().decode([ExerciseLog].self, from: exercisesData)) ?? [] }
        set { exercisesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var paceSecPerKm: Double? {
        guard let d = distanceM, d > 0 else { return nil }
        return Double(durationSec) / (d / 1000)
    }
    var volumeKg: Double {
        exercises.flatMap(\.sets).filter(\.done).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }
    var prCount: Int { exercises.flatMap(\.sets).filter(\.isPR).count }
}

@Model
final class SleepSession {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var start: Date = Date()
    var end: Date = Date()
    var stagesData: Data = Data()
    var hrvMs: Double?
    var restingHR: Double?
    var quality: Int?          // 1–5
    var sourceRaw: String = SleepSource.manual.rawValue
    var healthKitUUID: String?

    var stages: [SleepStageSegment] {
        get { (try? JSONDecoder().decode([SleepStageSegment].self, from: stagesData)) ?? [] }
        set { stagesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var source: SleepSource {
        get { SleepSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}

@Model
final class DailyMetric {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var day: Date = Date()      // startOfDay
    var steps: Int?
    var activeKcal: Double?
}

@Model
final class CoachMessage {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var roleRaw: String = MessageRole.user.rawValue
    var text: String = ""
    var actionsData: Data = Data()

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }
    var actions: [CoachAction] {
        get { (try? JSONDecoder().decode([CoachAction].self, from: actionsData)) ?? [] }
        set { actionsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

@Model
final class MemoryItem {
    init() {}

    @Attribute(.unique) var id: UUID = UUID()
    var createdAt: Date = Date()
    var kindRaw: String = MemoryKind.fact.rawValue
    var text: String = ""
    var dueDate: Date?
    var isDone: Bool = false

    var kind: MemoryKind {
        get { MemoryKind(rawValue: kindRaw) ?? .fact }
        set { kindRaw = newValue.rawValue }
    }
}
