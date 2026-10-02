import Foundation
import SwiftData

nonisolated enum ContextBuilder {

    /// Assembles the full CoachContext for "now" from the store + services.
    static func build(modelContext: ModelContext, events: [CalendarEventInfo],
                      now: Date) -> CoachContext {
        var cal = Calendar.current
        cal.timeZone = .current
        var c = CoachContext(now: now)

        let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
        c.userName = profile?.name ?? ""
        c.tone = profile?.coachTone ?? .direct
        c.units = profile?.unitSystem ?? .imperial

        let goal = try? modelContext.fetch(FetchDescriptor<Goal>(
            predicate: #Predicate { $0.isActive == true }
        )).first

        let plan = try? modelContext.fetch(FetchDescriptor<PlanSnapshot>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )).first
        if let plan {
            c.plan = PlanSnapshotValue(
                kcalTarget: plan.kcalTarget, proteinG: plan.proteinG,
                carbsG: plan.carbsG, fatG: plan.fatG,
                sleepTargetMin: plan.sleepTargetMin,
                weeklySplit: plan.weeklySplit, rationale: plan.rationale)
            c.weekSplit = plan.weeklySplit
        }

        // MARK: Measurements + goal projection
        let measurements = (try? modelContext.fetch(FetchDescriptor<Measurement>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []
        if let goal {
            let metricValues = measurements.filter { $0.metric == goal.metric }
                .map { (date: $0.date, value: $0.value) }
            let current = metricValues.last?.value ?? goal.baseline
            let projection = ProjectionEngine.project(
                baseline: goal.baseline, start: goal.startDate,
                measurements: metricValues, target: goal.target,
                targetDate: goal.targetDate, now: now)
            c.goal = GoalSnapshot(
                kind: goal.kind, title: goal.title, metric: goal.metric,
                customUnit: goal.customUnit, baseline: goal.baseline,
                current: current, target: goal.target,
                startDate: goal.startDate, targetDate: goal.targetDate,
                daysLeft: Int(goal.targetDate.timeIntervalSince(now) / 86400),
                projection: projection)
        }

        // MARK: Targets
        if let profile {
            let input = ProfileInput(sex: profile.sex, age: profile.age,
                                     heightCm: profile.heightCm, weightKg: profile.weightKg,
                                     activityLevel: profile.activityLevel, dietStyle: profile.dietStyle)
            c.targets = NutritionEngine.targets(for: input, goal: goal?.kind ?? .custom)
        } else if let plan {
            c.targets = MacroTargets(kcal: plan.kcalTarget, proteinG: plan.proteinG,
                                     carbsG: plan.carbsG, fatG: plan.fatG)
        }

        // MARK: Meals today
        let startOfDay = cal.startOfDay(for: now)
        let meals = (try? modelContext.fetch(FetchDescriptor<MealEntry>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []
        let todaysMeals = meals.filter { $0.date >= startOfDay && $0.date <= now }
        c.mealsToday = todaysMeals.map {
            MealSnapshot(id: $0.id, date: $0.date, title: $0.title, mealType: $0.mealType,
                         kcal: $0.totalKcal, protein: $0.totalProtein,
                         carbs: $0.totalCarbs, fat: $0.totalFat, hasPhoto: $0.photo != nil)
        }
        c.eaten = todaysMeals.reduce(MacroTotals()) {
            $0 + MacroTotals(kcal: $1.totalKcal, protein: $1.totalProtein,
                             carbs: $1.totalCarbs, fat: $1.totalFat)
        }
        c.remaining = MacroTotals(kcal: Double(c.targets.kcal) - c.eaten.kcal,
                                  protein: Double(c.targets.proteinG) - c.eaten.protein,
                                  carbs: Double(c.targets.carbsG) - c.eaten.carbs,
                                  fat: Double(c.targets.fatG) - c.eaten.fat)

        // MARK: Eating window
        if let w = profile?.eatingWindow {
            c.eatingWindow = eatingWindowState(open: w.open, close: w.close, now: now, cal: cal)
        }

        // MARK: Sleep
        let sleeps = (try? modelContext.fetch(FetchDescriptor<SleepSession>(
            sortBy: [SortDescriptor(\.end, order: .reverse)]
        ))) ?? []
        let recent = Array(sleeps.prefix(14))
        // Baselines from the previous 14 nights (excluding last night).
        let baselineSleeps = Array(recent.dropFirst())
        c.hrvBaseline = mean(baselineSleeps.compactMap(\.hrvMs))
        c.rhrBaseline = mean(baselineSleeps.compactMap(\.restingHR))

        // Sleep need uses load — compute below then score.
        let workouts = (try? modelContext.fetch(FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
        let loadPairs = workouts.map { (date: $0.date, load: $0.load) }
        c.load = ScoreEngine.trainingLoad(workouts: loadPairs, now: now, calendar: cal)

        var debt = 0
        if baselineSleeps.count >= 3 {
            let avg = baselineSleeps.reduce(0) { $0 + asleepMinutes($1) } / baselineSleeps.count
            debt = max(0, 480 - Int(avg))
        }
        c.sleepNeedMin = ScoreEngine.sleepNeed(baseMin: plan?.sleepTargetMin ?? 480,
                                               acuteLoad: c.load.acute7,
                                               chronicLoad: c.load.chronic28,
                                               debtMin: debt)

        c.recentSleep = recent.prefix(7).reversed().map { last -> SleepSummary in
            var s = ScoreEngine.sleepSummary(SleepInput(
                start: last.start, end: last.end, stages: last.stages,
                hrvMs: last.hrvMs, restingHR: last.restingHR, quality: last.quality))
            s.score = ScoreEngine.sleepScore(summary: s, needMin: c.sleepNeedMin,
                                             recentBedtimes: recent.map(\.start))
            return s
        }
        if let last = recent.first {
            var summary = ScoreEngine.sleepSummary(SleepInput(
                start: last.start, end: last.end, stages: last.stages,
                hrvMs: last.hrvMs, restingHR: last.restingHR, quality: last.quality))
            let bedtimes = recent.map(\.start)
            summary.score = ScoreEngine.sleepScore(summary: summary, needMin: c.sleepNeedMin,
                                                   recentBedtimes: bedtimes)
            c.lastSleep = summary
            c.recoveryScore = ScoreEngine.recoveryScore(
                sleepScore: summary.score, hrv: summary.hrvMs, hrvBaseline: c.hrvBaseline,
                rhr: summary.restingHR, rhrBaseline: c.rhrBaseline)
            if let h = summary.hrvMs, let b = c.hrvBaseline, b > 0 {
                c.hrvDeltaPct = (h - b) / b * 100
            }
            if let r = summary.restingHR, let b = c.rhrBaseline {
                c.rhrDelta = r - b
            }
        }

        // MARK: Workouts
        c.completedToday = workouts.filter { cal.isDate($0.date, inSameDayAs: now) }.map { snapshot($0) }
        c.recentWorkouts = workouts.filter { now.timeIntervalSince($0.date) <= 14 * 86400 }.map { snapshot($0) }
        c.todaySession = ProgramGenerator.session(on: now, split: c.weekSplit, calendar: cal)

        // MARK: Calendar
        c.events = events.filter { cal.isDate($0.start, inSameDayAs: now) }
        c.tomorrowFirstEvent = events
            .filter { $0.start >= now }
            .sorted { $0.start < $1.start }
            .first
        c.recommendedBedtime = ScoreEngine.recommendedBedtime(
            firstEventTomorrow: c.tomorrowFirstEvent, needMin: c.sleepNeedMin,
            now: now, calendar: cal)

        // MARK: Memories + steps
        let memories = (try? modelContext.fetch(FetchDescriptor<MemoryItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? []
        c.memories = memories.filter { !$0.isDone }.map {
            MemorySnapshot(id: $0.id, kind: $0.kind, text: $0.text, dueDate: $0.dueDate)
        }
        let metrics = (try? modelContext.fetch(FetchDescriptor<DailyMetric>())) ?? []
        c.steps = metrics.first { cal.isDate($0.day, inSameDayAs: now) }?.steps

        return c
    }

    // MARK: - Helpers

    private static func snapshot(_ w: Workout) -> WorkoutSnapshot {
        WorkoutSnapshot(id: w.id, date: w.date, kind: w.kind, title: w.title,
                        durationMin: w.durationSec / 60, load: w.load, sport: w.sport)
    }

    private static func mean(_ xs: [Double]) -> Double? {
        xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }

    private static func asleepMinutes(_ s: SleepSession) -> Int {
        let stages = s.stages
        if stages.isEmpty {
            return Int(s.end.timeIntervalSince(s.start) / 60)
        }
        return Int(stages.filter { $0.stage != .awake }.reduce(0) { $0 + $1.minutes })
    }

    /// Eating window state (minutes after midnight open..close).
    static func eatingWindowState(open: Int, close: Int, now: Date,
                                  cal: Calendar) -> EatingWindowState? {
        let today = cal.startOfDay(for: now)
        let opens = today.addingTimeInterval(Double(open) * 60)
        let closes = today.addingTimeInterval(Double(close) * 60)
        if now < opens {
            return EatingWindowState(opens: opens, closes: closes, isOpen: false,
                                     nextChange: opens,
                                     minutesToNextChange: Int(opens.timeIntervalSince(now) / 60))
        } else if now < closes {
            return EatingWindowState(opens: opens, closes: closes, isOpen: true,
                                     nextChange: closes,
                                     minutesToNextChange: Int(closes.timeIntervalSince(now) / 60))
        } else {
            let next = opens.addingTimeInterval(86400)
            return EatingWindowState(opens: opens, closes: closes, isOpen: false,
                                     nextChange: next,
                                     minutesToNextChange: Int(next.timeIntervalSince(now) / 60))
        }
    }
}
