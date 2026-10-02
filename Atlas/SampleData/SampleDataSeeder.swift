import Foundation
import SwiftData
import UIKit

/// Seeds the demo persona "Marcus" — 6 weeks into a 16-week vertical goal.
/// Everything is relative to `now` (AppClock.now) so data looks realistic
/// at any time of day.
@MainActor struct SampleDataSeeder {

    func seed(into ctx: ModelContext, now: Date) {
        var cal = Calendar.current
        cal.timeZone = .current
        let today = cal.startOfDay(for: now)

        // MARK: Profile — Marcus, 24, 6'2", 185 lb
        let p = UserProfile()
        p.name = "Marcus"
        p.sex = .male
        p.birthYear = cal.component(.year, from: now) - 24
        p.heightCm = 188
        p.weightKg = 84
        p.activityLevel = .moderate
        p.experience = .intermediate
        p.trainingDaysPerWeek = 4
        p.equipment = .gym
        p.dietStyle = .highProtein
        p.allergies = []
        p.fastingStartMinutes = 720   // 12:00
        p.fastingEndMinutes = 1200    // 20:00
        p.unitSystem = .imperial
        p.coachTone = .direct
        p.createdAt = today.addingTimeInterval(-42 * 86400)
        p.onboardingComplete = true
        p.isSampleData = true
        ctx.insert(p)
        // MARK: Goal — vertical 24.5" → 30", 16 weeks, started 6 weeks ago
        let goal = Goal()
        goal.kind = .vertical
        goal.title = "Jump higher"
        goal.metric = .verticalJump
        goal.baseline = 62.23          // 24.5"
        goal.target = 76.2             // 30"
        goal.startDate = today.addingTimeInterval(-42 * 86400)
        goal.targetDate = goal.startDate.addingTimeInterval(16 * 7 * 86400)
        goal.isActive = true
        ctx.insert(goal)
        // MARK: Measurements — every ~5–7 days, trending to ~26" with noise
        var rng = SeededRNG(seed: 42)
        let measurementDays = [40, 34, 28, 22, 17, 11, 6, 1]
        let startVal = 62.23
        let endVal = 66.04             // 26"
        for (i, daysAgo) in measurementDays.enumerated() {
            let m = Measurement()
            m.date = today.addingTimeInterval(TimeInterval(-daysAgo * 86400 + 8 * 3600))
            m.metric = .verticalJump
            let t = Double(i) / Double(measurementDays.count - 1)
            m.value = startVal + (endVal - startVal) * t + rng.gaussian() * 0.5
            ctx.insert(m)
        }
        // Body weight alongside.
        for daysAgo in [40, 26, 12, 1] {
            let m = Measurement()
            m.date = today.addingTimeInterval(TimeInterval(-daysAgo * 86400 + 8 * 3600))
            m.metric = .bodyWeight
            m.value = 84.5 - Double(40 - daysAgo) * 0.02 + rng.gaussian() * 0.3
            ctx.insert(m)
        }
        // MARK: Plan snapshot from engines
        let targets = NutritionEngine.targets(for: ProfileInput(
            sex: .male, age: 24, heightCm: 188, weightKg: 84,
            activityLevel: .moderate, dietStyle: .highProtein), goal: .vertical)
        let split = ProgramGenerator.weeklySplit(goal: .vertical, daysPerWeek: 4,
                                                 equipment: .gym, experience: .intermediate)
        let plan = PlanSnapshot()
        plan.createdAt = goal.startDate
        plan.kcalTarget = targets.kcal
        plan.proteinG = targets.proteinG
        plan.carbsG = targets.carbsG
        plan.fatG = targets.fatG
        plan.sleepTargetMin = 480
        plan.weeklySplit = split
        plan.rationale = "Marcus is training for elastic power: plyometrics paired with heavy lower-body strength 4×/week, \(Fmt.kcal(Double(targets.kcal))) kcal/day and \(targets.proteinG) g protein to stay explosive."
        ctx.insert(plan)
        // MARK: Sleep — 21 nights, baseline HRV ~68 ms / RHR ~52, last night bad
        for nightsAgo in (1...21).reversed() {
            let isLastNight = nightsAgo == 1
            let wakeDay = today.addingTimeInterval(TimeInterval(-nightsAgo * 86400))
            // Bed ~23:15 ± noise; wake per duration.
            var bedtime = wakeDay.addingTimeInterval(-3600 * Double(Int.random(in: 0...0)))
            // Previous evening 23:00–23:45.
            bedtime = wakeDay.addingTimeInterval(-8.2 * 3600 - rng.next() * 3600 - 15 * 3600)
            let asleepMin: Double
            let eff: Double
            let hrv: Double
            let rhr: Double
            if isLastNight {
                asleepMin = 340   // 5h 40m
                eff = 0.78
                hrv = 68 * 0.82   // ~18% under baseline
                rhr = 56          // +4
            } else {
                asleepMin = 400 + rng.gaussian() * 40   // ~6h 40m avg
                eff = 0.88 + rng.next() * 0.08
                hrv = 68 + rng.gaussian() * 6
                rhr = 52 + rng.gaussian() * 2
            }
            let inBed = asleepMin / eff
            let end = bedtime.addingTimeInterval(inBed * 60)
            let s = SleepSession()
            s.start = bedtime
            s.end = end
            s.stages = sleepStages(start: bedtime, end: end, asleepMin: asleepMin, rng: &rng)
            s.hrvMs = max(30, hrv)
            s.restingHR = rhr
            s.source = .sample
            ctx.insert(s)
        }
        // MARK: Workouts — per split + Thursday basketball + Zone 2 runs
        let foodDB = FoodDatabase.shared
        _ = foodDB
        var workoutCount = 0
        for daysAgo in (0...21).reversed() {
            let day = today.addingTimeInterval(TimeInterval(-daysAgo * 86400))
            let weekday = cal.component(.weekday, from: day) // 1=Sun
            let monday1 = weekday == 1 ? 7 : weekday - 1

            if daysAgo == 0 { break } // today's session not done yet
            if let planned = split.first(where: { $0.weekday == monday1 }) {
                let w = Workout()
                w.date = day.addingTimeInterval(18 * 3600) // ~6 PM
                w.kind = planned.kind
                w.title = planned.title
                w.durationSec = planned.durationMin * 60 - Int(rng.next() * 600)
                w.rpe = 7 + rng.next() * 1.5
                w.source = .sample
                // Progressive overload: strength exercises get sets, weights
                // creep up over the 3 weeks.
                var logs: [ExerciseLog] = []
                for block in planned.blocks where block.title.contains("Strength") || block.title.contains("lift") {
                    for pe in block.exercises.prefix(3) {
                        let weeks = Double(21 - daysAgo) / 7
                        let base = baseWeight(for: pe.exerciseId)
                        var sets: [SetLog] = []
                        for _ in 0..<pe.sets {
                            let reps = Int(pe.reps.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "8") ?? 8
                            sets.append(SetLog(weightKg: base + weeks * 2.5, reps: reps,
                                               rpe: w.rpe, done: true))
                        }
                        logs.append(ExerciseLog(exerciseId: pe.exerciseId, name: pe.name,
                                                muscle: ExerciseLibrary.shared.entry(id: pe.exerciseId)?.muscle ?? "Full body",
                                                sets: sets))
                    }
                }
                w.exercises = logs
                w.load = ScoreEngine.sessionLoad(durationMin: w.durationSec / 60, rpe: w.rpe ?? 7)
                ctx.insert(w)
                workoutCount += 1
            }
            // Thursday pickup basketball (sport, 90 min RPE 7).
            if weekday == 5 {
                let w = Workout()
                w.date = day.addingTimeInterval(19 * 3600)
                w.kind = .sport
                w.title = "Pickup basketball"
                w.sport = "Basketball"
                w.durationSec = 90 * 60
                w.rpe = 7
                w.avgHR = 148
                w.source = .sample
                w.load = ScoreEngine.sessionLoad(durationMin: 90, rpe: 7)
                ctx.insert(w)
                workoutCount += 1
            }
            // Sunday Zone 2 run.
            if weekday == 1 {
                let w = Workout()
                w.date = day.addingTimeInterval(9 * 3600)
                w.kind = .cardio
                w.title = "Zone 2 run"
                w.durationSec = 32 * 60
                w.distanceM = 5200 + rng.gaussian() * 300
                w.avgHR = 138
                w.rpe = 5
                w.source = .sample
                w.load = ScoreEngine.sessionLoad(durationMin: 32, rpe: 5)
                ctx.insert(w)
                workoutCount += 1
            }
        }
        _ = workoutCount
        // MARK: Meals — 21 days, 2–4/day inside 12–20 window, today only before now
        let mealPool = mealTemplates()
        let photoNames = bundledSamplePhotos()
        for daysAgo in (0...21).reversed() {
            let day = today.addingTimeInterval(TimeInterval(-daysAgo * 86400))
            let count = Int.random(in: 2...4)
            // Meal times inside window: 12:00–12:45, 15:00, 18:30, 19:30.
            let slots = [(12, 15), (15, 0), (18, 30), (19, 45)]
            for i in 0..<count {
                let slot = slots[i]
                let date = day.addingTimeInterval(TimeInterval(slot.0 * 3600 + slot.1 * 60 + Int(rng.next() * 1800)))
                // Today's meals only before now.
                if daysAgo == 0 && date >= now {
                    continue
                }
                if daysAgo == 0, date > now {
                    continue
                }
                let template = mealPool[(daysAgo + i * 3 + 7) % mealPool.count]
                let meal = MealEntry()
                meal.date = date
                meal.mealType = slot.0 < 14 ? .lunch : (slot.0 < 17 ? .snack : .dinner)
                meal.title = template.title
                meal.source = .sample
                var items: [FoodItem] = []
                for (fid, qty) in template.items {
                    if let entry = foodDB.entry(id: fid) {
                        items.append(entry.item(quantity: qty))
                    }
                }
                if items.isEmpty { continue }
                meal.items = items
                // ~30% of meals get a photo from the bundled samples.
                if !photoNames.isEmpty, rng.next() < 0.35,
                   let data = photoData(named: photoNames[(daysAgo * 3 + i) % photoNames.count]) {
                    meal.photo = data
                }
                ctx.insert(meal)
            }
        }
        // MARK: Steps — daily
        for daysAgo in (0...21).reversed() {
            let day = today.addingTimeInterval(TimeInterval(-daysAgo * 86400))
            let d = DailyMetric()
            d.day = day
            var steps = 7000 + Int(rng.next() * 4000)
            if daysAgo == 0 {
                // Partial day: scale by fraction of waking hours passed.
                let hour = cal.component(.hour, from: now)
                steps = max(600, Int(Double(steps) * Double(max(0, hour - 7)) / 15))
            }
            d.steps = steps
            d.activeKcal = 350 + rng.next() * 300
            ctx.insert(d)
        }
        // MARK: Memories
        func memory(_ kind: MemoryKind, _ text: String, due: Date? = nil) {
            let m = MemoryItem()
            m.kind = kind
            m.text = text
            m.dueDate = due
            m.createdAt = today.addingTimeInterval(-14 * 86400)
            ctx.insert(m)
        }
        memory(.fact, "Left knee tweaks on deep squats — keep box jumps ≤ 24″")
        memory(.preference, "Girlfriend is vegetarian — pick restaurants with good veg options")
        memory(.fact, "Plays pickup basketball Thursdays 7 PM")
        let retest = cal.date(byAdding: .day, value: 10, to: today)!
        memory(.task, "Re-test vertical on \(Fmt.date(retest))", due: retest)
        // MARK: Prior coach conversation (yesterday) with a done action
        let yesterday = today.addingTimeInterval(-86400)
        func msg(_ role: MessageRole, _ text: String, actions: [CoachAction] = [], atMinutes h: Int) {
            let m = CoachMessage()
            m.role = role
            m.text = text
            m.date = yesterday.addingTimeInterval(TimeInterval(h * 60))
            m.actions = actions
            ctx.insert(m)
        }
        msg(.user, "I have a work dinner tonight — how do I handle it?", atMinutes: 9)
        var doneAction = CoachAction(kind: .setReminder, title: "Wind-down reminder",
                                     subtitle: "10:00 PM", status: .done,
                                     resultNote: "Reminder set for 10:00 PM")
        doneAction.params = ["title": "Wind down", "body": "Lights out 10:45.", "fireISO": ""]
        msg(.coach, "Keep lunch light — ~550 kcal, 45 g protein. At dinner: lean protein, veg sides, skip the fried starters. You're inside your 12–8 PM window if you eat by 7:45.",
            actions: [doneAction], atMinutes: 9)
        msg(.user, "Done, reminder set.", atMinutes: 9)
        msg(.coach, "Nice. Box jumps tomorrow — sleep is your edge tonight.", atMinutes: 9)
    }

    // MARK: - Helpers

    private func sleepStages(start: Date, end: Date, asleepMin: Double,
                             rng: inout SeededRNG) -> [SleepStageSegment] {
        let asleep = asleepMin * 60
        let awake = end.timeIntervalSince(start) - asleep
        var stages: [SleepStageSegment] = []
        var t = start
        // stage, seconds — non-awake segments sum to asleepMin exactly.
        func seg(_ stage: SleepStage, _ seconds: Double) {
            stages.append(SleepStageSegment(stage: stage, start: t, end: t.addingTimeInterval(seconds)))
            t = t.addingTimeInterval(seconds)
        }
        seg(.core, asleep * 0.20)
        seg(.deep, asleep * 0.10)
        seg(.awake, awake / 2)
        seg(.core, asleep * 0.18)
        seg(.rem, asleep * 0.12)
        seg(.deep, asleep * 0.06)
        seg(.core, asleep * 0.14)
        seg(.awake, awake / 2)
        seg(.rem, asleep * 0.10)
        let covered = stages.reduce(0) { $0 + $1.minutes }
        let left = end.timeIntervalSince(start) / 60 - covered
        if left > 0.5 {
            seg(.core, left * 60)
        }
        return stages.filter { $0.minutes > 0.5 }
    }

    private func baseWeight(for exerciseId: String) -> Double {
        switch exerciseId {
        case "trap_bar_deadlift": return 120
        case "back_squat": return 100
        case "bulgarian_split_squat": return 24
        case "bench_press": return 80
        case "overhead_press": return 45
        case "barbell_row": return 70
        case "hip_thrust": return 130
        case "pull_ups": return 0
        case "nordic_curl": return 0
        case "goblet_squat": return 24
        case "romanian_deadlift": return 80
        case "leg_press": return 140
        case "lat_pulldown": return 60
        case "incline_db_press": return 30
        case "walking_lunges": return 16
        case "sumo_deadlift": return 100
        default: return 20
        }
    }

    private func bundledSamplePhotos() -> [String] {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json",
                                        subdirectory: "SampleMeals"),
              let manifest = try? JSONDecoder().decode([String: [String]].self,
                                                       from: Data(contentsOf: url)) else { return [] }
        return manifest.keys.sorted()
    }

    private func photoData(named name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg",
                                        subdirectory: "SampleMeals") else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Realistic meal templates: food ids + servings.
    private func mealTemplates() -> [(title: String, items: [(String, Double)])] {
        [
            ("Chicken rice bowl", [("chicken_breast", 1.5), ("white_rice", 1.5), ("broccoli", 1)]),
            ("Protein oats", [("oatmeal", 1.5), ("protein_shake", 1), ("banana", 1)]),
            ("Salmon + sweet potato", [("salmon", 1.2), ("sweet_potato", 1.5), ("asparagus", 1)]),
            ("Greek yogurt bowl", [("greek_yogurt", 1.5), ("granola", 0.5), ("blueberries", 1)]),
            ("Chipotle-style bowl", [("chipotle_bowl", 1)]),
            ("Eggs + avocado toast", [("egg", 3), ("avocado_toast", 1)]),
            ("Poke bowl", [("poke_bowl", 1)]),
            ("Beef + rice", [("ground_beef_90", 1.5), ("white_rice", 1), ("garden_salad", 1)]),
            ("Protein shake + banana", [("protein_shake", 1), ("banana", 1)]),
            ("Sushi night", [("sushi_roll", 2), ("edamame", 1), ("miso_soup", 1)]),
            ("Turkey sandwich", [("turkey_sandwich", 1), ("apple", 1)]),
            ("Pasta + chicken", [("pasta_marinara", 1.5), ("chicken_breast", 1)]),
            ("Cottage cheese + fruit", [("cottage_cheese", 1), ("apple", 1)]),
            ("Steak + potatoes", [("steak", 1), ("sweet_potato", 1), ("broccoli", 1)]),
        ]
    }
}


/// Deterministic RNG so sample data is stable.
nonisolated struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B9 : seed }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
    /// Standard normal via Box–Muller.
    mutating func gaussian() -> Double {
        let u1 = max(next(), 1e-10), u2 = next()
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}
