import Testing
import Foundation
@testable import Atlas

@MainActor
struct NutritionEngineTests {
    let marcus = ProfileInput(sex: .male, age: 24, heightCm: 188, weightKg: 84,
                            activityLevel: .moderate)

    @Test func mifflinStJeorKnownValues() {
        // BMR = 10*84 + 6.25*188 - 5*24 + 5 = 840 + 1175 - 120 + 5 = 1900
        // TDEE = 1900 * 1.55 = 2945 → vertical adj 1.02 → ~3004 → 3000
        let t = NutritionEngine.targets(for: marcus, goal: .vertical)
        #expect(t.kcal >= 2990 && t.kcal <= 3010)
        // Protein 2.0 g/kg = 168
        #expect(t.proteinG == 168)
        #expect(t.fatG == Int((0.8 * 84).rounded()))
        #expect(t.carbsG > 0)
        // Macros roughly sum to kcal.
        let sum = t.proteinG * 4 + t.carbsG * 4 + t.fatG * 9
        #expect(abs(Double(sum - t.kcal)) < 80)
    }

    @Test func goalAdjustments() {
        let fatLoss = NutritionEngine.targets(for: marcus, goal: .fatLoss)
        let muscle = NutritionEngine.targets(for: marcus, goal: .muscle)
        let maint = NutritionEngine.targets(for: marcus, goal: .run)
        #expect(fatLoss.kcal < maint.kcal)
        #expect(muscle.kcal > maint.kcal)
        #expect(muscle.proteinG == Int((2.2 * 84).rounded()))
    }

    @Test func floors() {
        let small = ProfileInput(sex: .female, age: 55, heightCm: 150, weightKg: 45,
                                 activityLevel: .sedentary)
        let t = NutritionEngine.targets(for: small, goal: .fatLoss)
        #expect(t.kcal >= 1200)
        let smallM = ProfileInput(sex: .male, age: 60, heightCm: 160, weightKg: 55,
                                  activityLevel: .sedentary)
        #expect(NutritionEngine.targets(for: smallM, goal: .waist).kcal >= 1500)
    }
}

@MainActor
struct ProgramGeneratorTests {
    @Test func dayCountAndWeekdays() {
        let split = ProgramGenerator.weeklySplit(goal: .vertical, daysPerWeek: 4,
                                                 equipment: .gym, experience: .intermediate)
        #expect(split.count == 4)
        #expect(Set(split.map(\.weekday)).count == 4)
        #expect(split.allSatisfy { (1...7).contains($0.weekday) })
        // Titles short.
        #expect(split.allSatisfy { $0.title.count <= 18 })
    }

    @Test func goalEmphasis() {
        let v = ProgramGenerator.weeklySplit(goal: .vertical, daysPerWeek: 4,
                                             equipment: .gym, experience: .intermediate)
        #expect(v.contains { $0.kind == .plyometric })
        let ids = v.flatMap { $0.blocks.flatMap(\.exercises).map(\.exerciseId) }
        #expect(ids.contains("depth_jumps"))

        let r = ProgramGenerator.weeklySplit(goal: .run, daysPerWeek: 3,
                                             equipment: .gym, experience: .beginner)
        #expect(r.allSatisfy { $0.kind == .cardio })
    }

    @Test func sessionLookup() {
        let split = ProgramGenerator.weeklySplit(goal: .vertical, daysPerWeek: 4,
                                                 equipment: .gym, experience: .intermediate)
        // A Monday.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let monday = cal.date(from: DateComponents(year: 2026, month: 9, day: 28))!
        let s = ProgramGenerator.session(on: monday, split: split, calendar: cal)
        #expect(s?.weekday == 1)
        // A Sunday → rest.
        let sunday = cal.date(from: DateComponents(year: 2026, month: 10, day: 4))!
        #expect(ProgramGenerator.session(on: sunday, split: split, calendar: cal) == nil)
    }
}

@MainActor
struct ScoreEngineTests {
    private func night(asleep: Int, quality: Int? = nil) -> SleepInput {
        let end = Date()
        let start = end.addingTimeInterval(-Double(asleep + 20) * 60)
        let stages = [
            SleepStageSegment(stage: .awake, start: start, end: start.addingTimeInterval(20 * 60)),
            SleepStageSegment(stage: .deep, start: start.addingTimeInterval(20 * 60),
                              end: start.addingTimeInterval(20 * 60 + Double(asleep) * 60 * 0.15)),
            SleepStageSegment(stage: .rem, start: start.addingTimeInterval(20 * 60 + Double(asleep) * 60 * 0.15),
                              end: start.addingTimeInterval(20 * 60 + Double(asleep) * 60 * 0.38)),
            SleepStageSegment(stage: .core, start: start.addingTimeInterval(20 * 60 + Double(asleep) * 60 * 0.38), end: end),
        ]
        return SleepInput(start: start, end: end, stages: stages, hrvMs: 70, restingHR: 52, quality: quality)
    }

    @Test func sleepScoreBounds() {
        let good = ScoreEngine.sleepSummary(night(asleep: 480))
        let goodScore = ScoreEngine.sleepScore(summary: good, needMin: 480)
        #expect(goodScore >= 80 && goodScore <= 100)

        let bad = ScoreEngine.sleepSummary(night(asleep: 300))
        let badScore = ScoreEngine.sleepScore(summary: bad, needMin: 480)
        #expect(badScore < goodScore)
        #expect((0...100).contains(badScore))
    }

    @Test func recoveryFallback() {
        // No HRV/RHR → sleep-only.
        let s = ScoreEngine.recoveryScore(sleepScore: 80, hrv: nil, hrvBaseline: nil, rhr: nil, rhrBaseline: nil)
        #expect(s == 80)
        // HRV way under baseline hurts.
        let low = ScoreEngine.recoveryScore(sleepScore: 80, hrv: 50, hrvBaseline: 70, rhr: 56, rhrBaseline: 52)
        let ok = ScoreEngine.recoveryScore(sleepScore: 80, hrv: 70, hrvBaseline: 70, rhr: 52, rhrBaseline: 52)
        #expect(low < ok)
    }

    @Test func trainingLoadRatio() {
        let now = Date()
        let heavy = (0..<7).map { (date: now.addingTimeInterval(-Double($0) * 86400), load: 600.0) }
        let load = ScoreEngine.trainingLoad(workouts: heavy, now: now)
        #expect(load.acute7 == 4200)
        #expect(load.ratio > 1.3)
        #expect(load.status == "High")
        let empty = ScoreEngine.trainingLoad(workouts: [], now: now)
        #expect(empty.status == "Low")
    }

    @Test func bedtime() {
        let ev = CalendarEventInfo(id: "x", title: "Standup",
                                   start: Date().addingTimeInterval(86400).addingTimeInterval(9 * 3600),
                                   end: Date())
        let bed = ScoreEngine.recommendedBedtime(firstEventTomorrow: ev, needMin: 480, now: Date())
        // wake = event - 75min, bed = wake - 480 - 15 = event - 570 min.
        #expect(abs(bed.timeIntervalSince(ev.start) + 570 * 60) < 1)
    }
}

@MainActor
struct ProjectionEngineTests {
    @Test func slopeAndStatus() {
        let now = Date()
        let start = now.addingTimeInterval(-42 * 86400)
        // 24.5"→30" over 16 wks: cm. Measurements trending up ~2.5 cm in 6 wks.
        let targetDate = start.addingTimeInterval(112 * 86400)
        let ms = [40, 30, 20, 10, 1].enumerated().map { (i, d) in
            (date: now.addingTimeInterval(-Double(d) * 86400), value: 62.23 + 0.15 * Double(i))
        }
        let p = ProjectionEngine.project(baseline: 62.23, start: start, measurements: ms,
                                         target: 76.2, targetDate: targetDate, now: now)
        #expect(p.slopePerDay > 0)
        #expect(p.projectedDate != nil)
        #expect(p.status == .onTrack || p.status == .ahead || p.status == .behind)
        #expect(p.progress > 0 && p.progress <= 1.2)
    }

    @Test func insufficientAndReached() {
        let now = Date()
        let p0 = ProjectionEngine.project(baseline: 62, start: now,
                                          measurements: [], target: 76,
                                          targetDate: now.addingTimeInterval(80 * 86400), now: now)
        #expect(p0.status == .insufficientData)
        let p1 = ProjectionEngine.project(baseline: 62, start: now,
                                          measurements: [(now, 77)], target: 76,
                                          targetDate: now, now: now)
        #expect(p1.status == .reached)
    }
}
