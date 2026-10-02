import Testing
import Foundation
import SwiftData
@testable import Atlas

@MainActor
struct GamePlanEngineTests {
    private func baseContext(now: Date = Date()) -> CoachContext {
        var c = CoachContext(now: now)
        c.userName = "Marcus"
        c.targets = MacroTargets(kcal: 3000, proteinG: 168, carbsG: 330, fatG: 67)
        c.eaten = MacroTotals(kcal: 600, protein: 40, carbs: 70, fat: 18)
        c.remaining = MacroTotals(kcal: 2400, protein: 128, carbs: 260, fat: 49)
        return c
    }

    @Test func atLeastThreeDirectives() {
        var c = baseContext()
        c.goal = GoalSnapshot(kind: .vertical, title: "Jump higher", metric: .verticalJump,
                              customUnit: nil, baseline: 62, current: 66, target: 76,
                              startDate: c.now.addingTimeInterval(-42 * 86400),
                              targetDate: c.now.addingTimeInterval(70 * 86400), daysLeft: 70,
                              projection: Projection(current: 66, slopePerDay: 0.1,
                                                     projectedDate: c.now.addingTimeInterval(60 * 86400),
                                                     status: .onTrack))
        let ds = GamePlanEngine.directives(context: c)
        #expect(ds.count >= 3)
        #expect(ds.allSatisfy { $0.title.count <= 90 && $0.detail.count <= 160 })
    }

    @Test func badSleepChangesOutput() {
        var c = baseContext()
        c.lastSleep = SleepSummary(start: c.now, end: c.now, asleepMin: 340, inBedMin: 430,
                                   efficiency: 0.79, awakeMin: 90, remMin: 60, coreMin: 220,
                                   deepMin: 60, hrvMs: 55, restingHR: 56, score: 30)
        c.hrvDeltaPct = -18
        c.recoveryScore = 35
        c.recommendedBedtime = c.now.addingTimeInterval(3600 * 9)
        let ds = GamePlanEngine.directives(context: c)
        #expect(ds.contains { $0.pillar == .recovery })
        #expect(ds.contains { $0.title.lowercased().contains("zone 2") || $0.detail.lowercased().contains("zone 2") })
    }

    @Test func dinnerEventYieldsDirectiveWithAction() {
        var c = baseContext()
        c.events = [CalendarEventInfo(id: "1", title: "Dinner at Nobu",
                                      start: c.now.addingTimeInterval(5 * 3600),
                                      end: c.now.addingTimeInterval(7 * 3600),
                                      location: "Nobu, 105 Hudson St")]
        let ds = GamePlanEngine.directives(context: c)
        let dinner = ds.first { $0.title.contains("Dinner") }
        #expect(dinner != nil)
        #expect(dinner?.action?.kind == .reserveTable || dinner?.action?.kind == .orderMeal)
    }

    @Test func eatingWindowStates() {
        var cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Before window (open 12:00): now = 9 AM.
        var c = baseContext(now: today.addingTimeInterval(9 * 3600))
        c.eatingWindow = EatingWindowState(opens: today.addingTimeInterval(12 * 3600),
                                           closes: today.addingTimeInterval(20 * 3600),
                                           isOpen: false,
                                           nextChange: today.addingTimeInterval(12 * 3600),
                                           minutesToNextChange: 180)
        #expect(GamePlanEngine.directives(context: c).contains { $0.title.contains("Window opens") })

        // Inside window, closing soon.
        c.now = today.addingTimeInterval(18.5 * 3600)
        c.eatingWindow = EatingWindowState(opens: today.addingTimeInterval(12 * 3600),
                                           closes: today.addingTimeInterval(20 * 3600),
                                           isOpen: true,
                                           nextChange: today.addingTimeInterval(20 * 3600),
                                           minutesToNextChange: 90)
        #expect(GamePlanEngine.directives(context: c).contains { $0.title.contains("closes in") })

        // Closed.
        c.now = today.addingTimeInterval(22 * 3600)
        c.eatingWindow = EatingWindowState(opens: today.addingTimeInterval(12 * 3600),
                                           closes: today.addingTimeInterval(20 * 3600),
                                           isOpen: false,
                                           nextChange: today.addingTimeInterval(36 * 3600),
                                           minutesToNextChange: 840)
        #expect(GamePlanEngine.directives(context: c).contains { $0.title.contains("Kitchen's closed") })
    }
}

@MainActor
struct RuleBasedCoachTests {
    private func context() -> CoachContext {
        var c = CoachContext(now: Date())
        c.userName = "Marcus"
        c.targets = MacroTargets(kcal: 3000, proteinG: 168, carbsG: 330, fatG: 67)
        c.eaten = MacroTotals(kcal: 700, protein: 50, carbs: 80, fat: 20)
        c.remaining = MacroTotals(kcal: 2300, protein: 118, carbs: 250, fat: 47)
        c.lastSleep = SleepSummary(start: c.now, end: c.now, asleepMin: 340, inBedMin: 430,
                                   efficiency: 0.79, awakeMin: 90, remMin: 60, coreMin: 220,
                                   deepMin: 60, hrvMs: 56, restingHR: 56, score: 58)
        c.hrvDeltaPct = -18
        c.hrvBaseline = 68
        c.recoveryScore = 45
        c.sleepNeedMin = 495
        c.recommendedBedtime = Calendar.current.date(bySettingHour: 22, minute: 45, second: 0, of: c.now)!
        c.events = [CalendarEventInfo(id: "1", title: "Dinner at Nobu",
                                      start: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: c.now)!,
                                      end: Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: c.now)!,
                                      location: "Nobu, 105 Hudson St")]
        c.todaySession = PlannedSession(weekday: 1, title: "Lower power",
                                        focus: "Plyometrics + strength", kind: .plyometric,
                                        durationMin: 70,
                                        blocks: [PlannedBlock(title: "Plyometrics",
                                                              exercises: [PlannedExercise(exerciseId: "depth_jumps", name: "Depth jumps", sets: 3, reps: "5", cue: "Land soft")])])
        c.goal = GoalSnapshot(kind: .vertical, title: "Jump higher", metric: .verticalJump,
                              customUnit: nil, baseline: 62.2, current: 66, target: 76.2,
                              startDate: c.now.addingTimeInterval(-42 * 86400),
                              targetDate: c.now.addingTimeInterval(70 * 86400), daysLeft: 70,
                              projection: Projection(current: 66, slopePerDay: 0.15,
                                                     projectedDate: c.now.addingTimeInterval(66 * 86400),
                                                     status: .onTrack, daysVsTarget: 4))
        return c
    }

    @Test func nobuDinner() async throws {
        let r = try await RuleBasedCoach().respond(to: "I have dinner at Nobu at 7:30 tonight",
                                                   history: [], context: context())
        #expect(r.text.contains("7:30") || r.text.contains("Nobu"))
        #expect(r.actions.contains { $0.kind == .reserveTable })
        #expect(r.actions.contains { $0.kind == .orderMeal })
        #expect(!r.memoryWrites.isEmpty)
        // Bare hour + dinner/tonight → PM: 19:30 the same day.
        let res = r.actions.first { $0.kind == .reserveTable }
        let iso = res?.params["dateISO"].flatMap { ISO8601DateFormatter().date(from: $0) }
        let comps = iso.map { Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
        #expect(comps?.hour == 19 && comps?.minute == 30)
        let nowComps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        #expect(comps?.year == nowComps.year && comps?.month == nowComps.month && comps?.day == nowComps.day)
    }

    @Test func bareEveningHoursArePM() async throws {
        for (prompt, hour) in [("I have dinner at 8 tonight", 20), ("drinks at 9", 21)] {
            let r = try await RuleBasedCoach().respond(to: prompt, history: [], context: context())
            let res = r.actions.first { $0.kind == .reserveTable }
            let iso = res?.params["dateISO"].flatMap { ISO8601DateFormatter().date(from: $0) }
            #expect(iso.map { Calendar.current.component(.hour, from: $0) } == hour)
        }
    }


    @Test func sleptBadly() async throws {
        let r = try await RuleBasedCoach().respond(to: "I slept badly", history: [], context: context())
        #expect(r.text.contains("5h 40m") || r.text.contains("score 58") || r.text.contains("HRV"))
        #expect(r.text.lowercased().contains("zone 2") || r.text.lowercased().contains("mobility"))
        #expect(r.actions.contains { $0.kind == .setReminder })
    }

    @Test func onTrack() async throws {
        let r = try await RuleBasedCoach().respond(to: "Am I on track?", history: [], context: context())
        #expect(r.text.contains("66") || r.text.contains("26"))
        #expect(r.text.lowercased().contains("track") || r.text.lowercased().contains("projected"))
    }

    @Test func logMeal() async throws {
        let r = try await RuleBasedCoach().respond(to: "I ate 2 eggs and toast", history: [], context: context())
        #expect(r.logs.contains { log in
            if case .meal(_, _, let items) = log { return !items.isEmpty }
            return false
        })
        #expect(r.text.contains("kcal"))
    }

    @Test func remember() async throws {
        let r = try await RuleBasedCoach().respond(to: "Remember that my left knee hurts on deep squats",
                                                   history: [], context: context())
        #expect(!r.memoryWrites.isEmpty)
    }
}

@MainActor
struct MemoryExtractorTests {
    @Test func extracts() {
        #expect(!MemoryExtractor.extract(from: "remember that I fly to NYC next week").isEmpty)
        #expect(MemoryExtractor.extract(from: "remember that I fly to NYC next week").first?.kind == .task)
        #expect(!MemoryExtractor.extract(from: "my knee hurts when I squat deep").isEmpty)
        #expect(!MemoryExtractor.extract(from: "my girlfriend is vegetarian").isEmpty)
        #expect(!MemoryExtractor.extract(from: "I play pickup every Thursday").isEmpty)
        #expect(MemoryExtractor.extract(from: "what's for lunch").isEmpty)
    }
}
