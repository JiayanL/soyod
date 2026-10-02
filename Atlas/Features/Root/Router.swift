import SwiftUI
import UIKit
import SwiftData

enum AppSheet: Identifiable {
    case memory
    case quickLog
    case logMeal(MealType?)
    case snap
    case snapReview(SnapInput)
    case mealDetail(UUID)
    case logger(PlannedSession?)
    case workoutSummary(WorkoutSaveResult)
    case cardio
    case manualSleep
    case measurement
    case settings
    case integrations

    var id: String {
        switch self {
        case .memory: "memory"
        case .quickLog: "quickLog"
        case .logMeal(let t): "logMeal-\(t?.rawValue ?? "")"
        case .snap: "snap"
        case .snapReview(let input): "snapReview-\(input.id)"
        case .mealDetail(let id): "meal-\(id)"
        case .logger(let s): "logger-\(s?.id.uuidString ?? "free")"
        case .workoutSummary(let r): "summary-\(r.workout.id)"
        case .cardio: "cardio"
        case .manualSleep: "manualSleep"
        case .measurement: "measurement"
        case .settings: "settings"
        case .integrations: "integrations"
        }
    }
}

struct SnapInput: Identifiable {
    let id = UUID()
    let image: UIImage
    var name: String? = nil   // bundled sample photo base name, if any
}

/// UI navigation state shared across tabs.
@Observable @MainActor
final class Router {
    var sheet: AppSheet?
    var coachPath: [CoachDestination] = []
    var chatPrefill: String?
    var chatAutoSend = false

    func openChat(prefill: String? = nil) {
        chatPrefill = prefill
        if coachPath.last != .chat { coachPath.append(.chat) }
    }

    /// Apply a launch / deep-link route.
    func apply(_ route: LaunchRoute, app: AppState) {
        sheet = nil
        coachPath = []
        switch route {
        case .coach: app.selectedTab = .coach
        case .chat, .chatAction:
            app.selectedTab = .coach
            coachPath = [.chat]
            if route == .chatAction {
                chatPrefill = "I have dinner at Nobu at 7:30 tonight"
                chatAutoSend = true
            }
        case .memory:
            app.selectedTab = .coach
            coachPath = [.chat]
            sheet = .memory
        case .fuel: app.selectedTab = .fuel
        case .logMeal: app.selectedTab = .fuel; sheet = .logMeal(nil)
        case .snapReview:
            app.selectedTab = .fuel
            if let image = SampleMealPhotos.image(named: "chicken_rice_bowl") {
                sheet = .snapReview(SnapInput(image: image, name: "chicken_rice_bowl"))
            }
        case .train: app.selectedTab = .train
        case .logger:
            app.selectedTab = .train
            sheet = .logger(app.context.todaySession ?? app.context.weekSplit.first)
        case .workoutSummary:
            app.selectedTab = .train
            // Deep link / screenshot route: wrap the most recent workout.
            var d = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            d.fetchLimit = 1
            if let w = try? app.modelContext.fetch(d).first {
                // Same PR detection as save: exercise best e1RM vs all earlier workouts.
                let all = (try? app.modelContext.fetch(FetchDescriptor<Workout>())) ?? []
                let prior = all.filter { $0.date < w.date }
                let prs = w.exercises.compactMap { ex -> PRRecord? in
                    guard let best = ex.sets.filter(\.done).max(by: { $0.e1RM < $1.e1RM }) else { return nil }
                    let priorBest = prior.flatMap { pw in
                        pw.exercises.filter { $0.exerciseId == ex.exerciseId }
                            .flatMap(\.sets).filter(\.done).map(\.e1RM)
                    }.max() ?? 0
                    guard best.e1RM > priorBest else { return nil }
                    return PRRecord(exerciseName: ex.name, weightKg: best.weightKg,
                                    reps: best.reps, e1RM: best.e1RM)
                }
                sheet = .workoutSummary(WorkoutSaveResult(workout: w, prs: prs))
            }
        case .cardioLog: app.selectedTab = .train; sheet = .cardio
        case .sleep: app.selectedTab = .sleep
        case .manualSleep: app.selectedTab = .sleep; sheet = .manualSleep
        case .progress: app.selectedTab = .progress
        case .measurement: app.selectedTab = .progress; sheet = .measurement
        case .settings: app.selectedTab = .progress; sheet = .settings
        case .integrations: app.selectedTab = .progress; sheet = .integrations
        case .onbWelcome, .onbGoal, .onbBaseline, .onbAbout, .onbFuel, .onbConnect, .onbPlan: break
        }
    }
}

enum CoachDestination: Hashable {
    case chat
}

/// Bundled sample meal photos (Resources/SampleMeals).
enum SampleMealPhotos {
    static func image(named name: String) -> UIImage? {
        for ext in ["jpg", "jpeg", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "SampleMeals")
                ?? Bundle.main.url(forResource: name, withExtension: ext),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }
}
