import Testing
import Foundation
import SwiftData
@testable import Atlas

@MainActor
struct FoodDatabaseTests {
    @Test func size() {
        #expect(FoodDatabase.shared.all.count >= 250)
    }

    @Test func search() {
        #expect(FoodDatabase.shared.bestMatch(for: "chicken")?.id == "chicken_breast")
        #expect(FoodDatabase.shared.bestMatch(for: "rice") != nil)
        #expect(FoodDatabase.shared.bestMatch(for: "sushi") != nil)
        #expect(!FoodDatabase.shared.search("protein").isEmpty)
    }

    @Test func quickPicks() {
        #expect(FoodDatabase.shared.quickPicks.count >= 10)
    }
}

@MainActor
struct FoodTextParserTests {
    @Test func basicParsing() {
        let items = FoodTextParser.parse("2 eggs, toast with avocado, black coffee")
        #expect(items.count == 3)
        let eggs = items.first { $0.foodId == "egg" }
        #expect(eggs?.quantity == 2)
    }

    @Test func unitsAndGrams() {
        let rice = FoodTextParser.parse("1 cup rice")
        #expect(rice.first?.foodId == "white_rice")
        let chicken = FoodTextParser.parse("200g chicken breast")
        let item = chicken.first { $0.foodId == "chicken_breast" }
        #expect(item != nil)
        // 200g / 172g serving ≈ 1.16
        #expect(abs((item?.quantity ?? 0) - 200.0 / 172.0) < 0.01)
    }

    @Test func articlesAndFractions() {
        #expect(FoodTextParser.parse("a banana").first?.quantity == 1)
        #expect(FoodTextParser.parse("an apple").first?.quantity == 1)
        let half = FoodTextParser.parse("half an avocado")
        #expect(half.first?.foodId == "avocado")
        #expect(half.first?.quantity == 0.5)
    }

    @Test func totals() {
        let items = FoodTextParser.parse("2 eggs")
        let item = items.first
        #expect(item != nil)
        #expect(abs(item!.kcal - 144) < 2)
    }
}

@MainActor
struct ExerciseLibraryTests {
    @Test func sizeAndSearch() {
        #expect(ExerciseLibrary.shared.all.count >= 80)
        #expect(ExerciseLibrary.shared.entry(id: "back_squat") != nil)
        #expect(!ExerciseLibrary.shared.search("squat").isEmpty)
        #expect(ExerciseLibrary.shared.search("").count == ExerciseLibrary.shared.all.count)
    }
}

@MainActor
struct SampleDataSeederTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([UserProfile.self, Goal.self, Atlas.Measurement.self, PlanSnapshot.self,
                             MealEntry.self, Workout.self, SleepSession.self, DailyMetric.self,
                             CoachMessage.self, MemoryItem.self])
        return try ModelContainer(for: schema,
                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func seedsEnoughData() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        SampleDataSeeder().seed(into: ctx, now: Date())
        try ctx.save()

        #expect((try ctx.fetchCount(FetchDescriptor<SleepSession>())) >= 14)
        #expect((try ctx.fetchCount(FetchDescriptor<MealEntry>())) >= 14)
        #expect((try ctx.fetchCount(FetchDescriptor<Workout>())) >= 14)
        #expect((try ctx.fetchCount(FetchDescriptor<Atlas.Measurement>())) >= 8)
        #expect((try ctx.fetchCount(FetchDescriptor<MemoryItem>())) >= 4)
        #expect((try ctx.fetchCount(FetchDescriptor<CoachMessage>())) >= 3)

        let profile = try ctx.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.name == "Marcus")
        #expect(profile?.isSampleData == true)
        #expect(profile?.onboardingComplete == true)
        #expect(profile?.eatingWindow?.open == 720)

        // Last night's sleep is the bad one (5h40m-ish).
        let sleeps = try ctx.fetch(FetchDescriptor<SleepSession>(sortBy: [SortDescriptor(\.end, order: .reverse)]))
        let last = sleeps.first!
        let asleepMin = last.stages.filter { $0.stage != .awake }.reduce(0) { $0 + $1.minutes }
        #expect(asleepMin > 300 && asleepMin < 380)
    }

    @Test func contextBuilds() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        SampleDataSeeder().seed(into: ctx, now: Date())
        try ctx.save()
        let c = ContextBuilder.build(modelContext: ctx, events: [], now: Date())
        #expect(c.userName == "Marcus")
        #expect(c.goal != nil)
        #expect(c.targets.kcal > 0)
        #expect(c.lastSleep != nil)
        #expect(!c.weekSplit.isEmpty)
        #expect(GamePlanEngine.directives(context: c).count >= 3)
    }
}

@MainActor
struct ActionURLBuilderTests {
    @Test func urls() {
        let date = ISO8601DateFormatter().date(from: "2026-10-02T19:30:00Z")!
        let ot = ActionURLBuilder.openTable(restaurant: "Nobu Malibu", partySize: 2, date: date)!
        #expect(ot.absoluteString.contains("opentable.com"))
        #expect(ot.absoluteString.contains("covers=2"))
        #expect(ot.absoluteString.contains("term=Nobu"))

        let dd = ActionURLBuilder.doorDash(query: "high protein bowl")!
        #expect(dd.absoluteString.contains("doordash.com"))

        let resy = ActionURLBuilder.resy(restaurant: "Nobu", partySize: 2, date: date)!
        #expect(resy.absoluteString.contains("resy.com"))
    }
}

@MainActor
struct FormattingTests {
    @Test func metricFormatting() {
        #expect(Fmt.metric(62.23, metric: .verticalJump, units: .imperial) == "24.5″")
        #expect(Fmt.metric(84, metric: .bodyWeight, units: .imperial) == "185 lb")
        #expect(Fmt.metric(1182, metric: .fiveK, units: .metric) == "19:42")
        #expect(Fmt.metricValue(66.04, metric: .verticalJump, units: .imperial) == "26.0″")
        #expect(abs(Fmt.canonical(fromDisplay: 24.5, metric: .verticalJump, units: .imperial) - 62.23) < 0.01)
    }

    @Test func misc() {
        #expect(Fmt.duration(minutes: 462) == "7h 42m")
        #expect(Fmt.kcal(1240) == "1,240")
        #expect(Fmt.grams(112.4) == "112")
        #expect(Fmt.weight(kg: 84, units: .imperial) == "185 lb")
        #expect(Fmt.distance(m: 5000, units: .imperial) == "3.11 mi")
        #expect(Fmt.pace(secPerKm: 300, units: .metric) == "5:00 /km")
        #expect(Fmt.relativeDay(Date()) == "Today")
    }
}
