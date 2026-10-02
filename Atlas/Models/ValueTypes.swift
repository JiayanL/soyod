import Foundation

// MARK: - Value types (Codable, Hashable, Identifiable, Sendable)

struct FoodItem: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var foodId: String?
    var name: String
    var servingDescription: String = "1 serving"
    var quantity: Double = 1
    var kcalPerServing: Double
    var proteinPerServing: Double
    var carbsPerServing: Double
    var fatPerServing: Double
    var confidence: Double?
    var emoji: String?

    var kcal: Double { kcalPerServing * quantity }
    var protein: Double { proteinPerServing * quantity }
    var carbs: Double { carbsPerServing * quantity }
    var fat: Double { fatPerServing * quantity }
}

struct SetLog: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var done: Bool = false
    var isPR: Bool = false

    /// Epley estimated 1RM.
    var e1RM: Double { weightKg * (1 + Double(reps) / 30) }
}

struct ExerciseLog: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var exerciseId: String
    var name: String
    var muscle: String
    var sets: [SetLog]
}

struct SleepStageSegment: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var stage: SleepStage
    var start: Date
    var end: Date
    var minutes: Double { end.timeIntervalSince(start) / 60 }
}

struct PlannedExercise: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var exerciseId: String
    var name: String
    var sets: Int
    var reps: String          // "5", "8–10", "20 min"
    var cue: String
    var targetWeightKg: Double?
}

struct PlannedBlock: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String         // "Plyometrics"
    var exercises: [PlannedExercise]
}

struct PlannedSession: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var weekday: Int          // 1 = Monday … 7 = Sunday
    var title: String         // "Lower power"
    var focus: String         // "Plyometrics + strength"
    var kind: WorkoutKind
    var durationMin: Int
    var blocks: [PlannedBlock]
}

enum CoachActionKind: String, Codable, CaseIterable, Sendable {
    case reserveTable, orderMeal, scheduleWorkout, setReminder, logMeal
}

enum ActionStatus: String, Codable, CaseIterable, Sendable {
    case proposed, inProgress, done, dismissed
}

struct CoachAction: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var kind: CoachActionKind
    var title: String
    var subtitle: String = ""
    var params: [String: String] = [:]
    var status: ActionStatus = .proposed
    var resultNote: String?

    var primaryLabel: String {
        switch kind {
        case .reserveTable:
            if let iso = params["dateISO"], let d = ISO8601DateFormatter().date(from: iso) {
                return "Book for \(Fmt.clock(d))"
            }
            return "Book table"
        case .orderMeal: return "Order"
        case .scheduleWorkout: return "Add to calendar"
        case .setReminder: return "Remind me"
        case .logMeal: return "Log it"
        }
    }

    var providerName: String {
        switch kind {
        case .reserveTable:
            return params["provider"] == "resy" ? "Resy" : "OpenTable"
        case .orderMeal:
            let p = params["provider"] ?? "doordash"
            switch p {
            case "ubereats": return "Uber Eats"
            case "resy": return "Resy"
            case "opentable": return "OpenTable"
            default: return "DoorDash"
            }
        case .scheduleWorkout: return "Calendar"
        case .setReminder: return "Reminder"
        case .logMeal: return "Atlas"
        }
    }

    var symbol: String {
        switch kind {
        case .reserveTable: return "fork.knife.circle"
        case .orderMeal: return "takeoutbag.and.cup.and.straw"
        case .scheduleWorkout: return "calendar.badge.plus"
        case .setReminder: return "bell.badge"
        case .logMeal: return "checkmark.circle"
        }
    }
}

struct Directive: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var pillar: Pillar
    var priority: Int
    var action: CoachAction?
}

struct MacroTargets: Codable, Hashable, Sendable {
    var kcal: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
}

struct MacroTotals: Codable, Hashable, Sendable {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    static func + (a: MacroTotals, b: MacroTotals) -> MacroTotals {
        MacroTotals(kcal: a.kcal + b.kcal, protein: a.protein + b.protein,
                    carbs: a.carbs + b.carbs, fat: a.fat + b.fat)
    }
    static func - (a: MacroTotals, b: MacroTotals) -> MacroTotals {
        MacroTotals(kcal: a.kcal - b.kcal, protein: a.protein - b.protein,
                    carbs: a.carbs - b.carbs, fat: a.fat - b.fat)
    }
}

struct Milestone: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var value: Double
    var title: String
    var isReached: Bool
}
