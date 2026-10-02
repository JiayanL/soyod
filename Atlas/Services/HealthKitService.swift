import Foundation
import SwiftData
#if canImport(HealthKit)
import HealthKit
#endif

struct ImportSummary: Sendable {
    var sleepNights: Int = 0
    var workouts: Int = 0
    var measurements: Int = 0
    var stepDays: Int = 0
}

@Observable
final class HealthKitService {
    enum Status: String, Sendable { case notDetermined, requested, unavailable }

    private(set) var status: Status = .notDetermined

    var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    private var readTypes: Set<HKObjectType> {
        let types: [HKObjectType?] = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
        ]
        return Set(types.compactMap { $0 })
    }

    private var writeTypes: Set<HKSampleType> {
        let types: [HKSampleType?] = [
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.workoutType(),
        ]
        return Set(types.compactMap { $0 })
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable, !LaunchOptions.current.denyPermissions else {
            status = .unavailable
            return false
        }
        #if canImport(HealthKit)
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            status = .requested
            return true
        } catch {
            status = .unavailable
            return false
        }
        #else
        status = .unavailable
        return false
        #endif
    }

    /// Imports the last `days` of sleep, workouts, HRV/RHR, weight, steps.
    /// Never throws — missing permissions or data just yield fewer imports.
    func importRecent(into context: ModelContext, days: Int = 30) async -> ImportSummary {
        var summary = ImportSummary()
        guard isAvailable, status == .requested, !LaunchOptions.current.denyPermissions else {
            return summary
        }
        #if canImport(HealthKit)
        let now = AppClock.now
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now)!

        // Workouts → Workout models (dedupe by HK UUID).
        do {
            let workouts = try await workoutSamples(from: start, to: now)
            for w in workouts {
                let uuid = w.uuid.uuidString
                if try context.fetchCount(FetchDescriptor<Workout>(
                    predicate: #Predicate { $0.healthKitUUID == uuid })) == 0 {
                    context.insert(map(workout: w))
                    summary.workouts += 1
                }
            }
        } catch {}

        // Sleep → SleepSession with stages.
        do {
            let nights = try await sleepSamples(from: start, to: now)
            let hrvByNight = (try? await hrvByNightMap(from: start, to: now)) ?? [:]
            let rhrByNight = (try? await rhrByNightMap(from: start, to: now)) ?? [:]
            for (nightStart, segments) in nights {
                let uuid = "sleep-\(Int(nightStart.timeIntervalSince1970))"
                guard (try? context.fetchCount(FetchDescriptor<SleepSession>(
                    predicate: #Predicate { $0.healthKitUUID == uuid }))) == 0 else { continue }
                let s = SleepSession()
                s.healthKitUUID = uuid
                s.source = .health
                s.start = segments.map(\.startDate).min() ?? nightStart
                s.end = segments.map(\.endDate).max() ?? nightStart
                s.stages = segments.compactMap { map(stage: $0) }
                s.hrvMs = hrvByNight[Calendar.current.startOfDay(for: s.end)]
                s.restingHR = rhrByNight[Calendar.current.startOfDay(for: s.end)]
                context.insert(s)
                summary.sleepNights += 1
            }
        } catch {}

        // Body mass → Measurement(.bodyWeight).
        do {
            let masses = try await quantitySamples(.bodyMass, from: start, to: now)
            for m in masses {
                let uuid = m.uuid.uuidString
                // Dedupe via HealthKit UUID stored in note field.
                if try context.fetchCount(FetchDescriptor<Measurement>(
                    predicate: #Predicate { $0.note == uuid })) == 0 {
                    let meas = Measurement()
                    meas.date = m.startDate
                    meas.metric = .bodyWeight
                    meas.value = m.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    meas.note = uuid
                    context.insert(meas)
                    summary.measurements += 1
                }
            }
        } catch {}

        // Steps → DailyMetric.
        do {
            let steps = try await stepsByDay(from: start, to: now)
            for (day, count) in steps {
                if let existing = try context.fetch(FetchDescriptor<DailyMetric>(
                    predicate: #Predicate { $0.day == day })).first {
                    existing.steps = count
                } else {
                    let d = DailyMetric()
                    d.day = day
                    d.steps = count
                    context.insert(d)
                }
                summary.stepDays += 1
            }
        } catch {}

        try? context.save()
        #endif
        return summary
    }

    // MARK: - Write (best effort)

    func save(meal: MealEntry) async {
        guard isAvailable, status == .requested else { return }
        #if canImport(HealthKit)
        var samples: [HKQuantitySample] = []
        func sample(_ id: HKQuantityTypeIdentifier, _ value: Double, _ unit: HKUnit) {
            guard let type = HKObjectType.quantityType(forIdentifier: id), value > 0 else { return }
            samples.append(HKQuantitySample(type: type,
                                            quantity: HKQuantity(unit: unit, doubleValue: value),
                                            start: meal.date, end: meal.date))
        }
        sample(.dietaryEnergyConsumed, meal.totalKcal, .kilocalorie())
        sample(.dietaryProtein, meal.totalProtein, .gram())
        sample(.dietaryCarbohydrates, meal.totalCarbs, .gram())
        sample(.dietaryFatTotal, meal.totalFat, .gram())
        if !samples.isEmpty { try? await store.save(samples) }
        #endif
    }

    func save(workout: Workout) async {
        guard isAvailable, status == .requested else { return }
        #if canImport(HealthKit)
        let activity: HKWorkoutActivityType
        switch workout.kind {
        case .strength: activity = .traditionalStrengthTraining
        case .cardio: activity = workout.title.lowercased().contains("ride") ? .cycling : .running
        case .sport: activity = .basketball
        case .mobility: activity = .flexibility
        case .plyometric: activity = .functionalStrengthTraining
        }
        let end = workout.date
        let start = end.addingTimeInterval(-Double(workout.durationSec))
        let hk = HKWorkout(activityType: activity, start: start, end: end,
                           duration: Double(workout.durationSec),
                           totalEnergyBurned: nil,
                           totalDistance: workout.distanceM.map { HKQuantity(unit: .meter(), doubleValue: $0) },
                           metadata: nil)
        try? await store.save(hk)
        #endif
    }

    // MARK: - HealthKit queries

    #if canImport(HealthKit)
    private func samples<T: HKSample>(of type: HKSampleType, from start: Date, to end: Date,
                                      limit: Int = HKObjectQueryNoLimit) async throws -> [T] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, s, e in
                if let e { cont.resume(throwing: e) } else { cont.resume(returning: (s as? [T]) ?? []) }
            }
            store.execute(q)
        }
    }

    private func workoutSamples(from start: Date, to end: Date) async throws -> [HKWorkout] {
        try await samples(of: HKObjectType.workoutType(), from: start, to: end)
    }

    private func sleepSamples(from start: Date, to end: Date) async throws -> [Date: [HKCategorySample]] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let all: [HKCategorySample] = try await samples(of: type, from: start, to: end)
        // Group segments into nights: a "night" ends in the morning; cluster
        // by proximity (gap > 3h starts a new session).
        var nights: [Date: [HKCategorySample]] = [:]
        var current: [HKCategorySample] = []
        var lastEnd: Date?
        for s in all {
            if let lastEnd, s.startDate.timeIntervalSince(lastEnd) > 3 * 3600 {
                if !current.isEmpty {
                    let key = Calendar.current.startOfDay(for: current.map(\.endDate).max() ?? start)
                    nights[key, default: []].append(contentsOf: current)
                }
                current = []
            }
            current.append(s)
            lastEnd = s.endDate
        }
        if !current.isEmpty {
            let key = Calendar.current.startOfDay(for: current.map(\.endDate).max() ?? start)
            nights[key, default: []].append(contentsOf: current)
        }
        return nights
    }

    private func map(stage s: HKCategorySample) -> SleepStageSegment? {
        let stage: SleepStage
        if #available(iOS 16.0, *) {
            switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
            case .awake, .inBed: stage = .awake
            case .asleepREM: stage = .rem
            case .asleepDeep: stage = .deep
            case .asleepCore, .asleepUnspecified: stage = .core
            default: return nil
            }
        } else {
            switch s.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue,
                 HKCategoryValueSleepAnalysis.inBed.rawValue: stage = .awake
            default: stage = .core
            }
        }
        return SleepStageSegment(stage: stage, start: s.startDate, end: s.endDate)
    }

    private func map(workout w: HKWorkout) -> Workout {
        let model = Workout()
        model.date = w.startDate
        model.healthKitUUID = w.uuid.uuidString
        model.source = .health
        model.durationSec = Int(w.duration)
        model.distanceM = w.totalDistance?.doubleValue(for: .meter())
        switch w.workoutActivityType {
        case .running, .walking, .cycling, .swimming, .rowing, .hiking, .elliptical:
            model.kind = .cardio
            model.title = w.workoutActivityType.atlasName
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            model.kind = .strength
            model.title = "Strength"
        case .yoga, .flexibility, .mindAndBody, .pilates:
            model.kind = .mobility
            model.title = "Mobility"
        case .basketball, .soccer, .tennis, .badminton, .volleyball, .hockey:
            model.kind = .sport
            model.sport = w.workoutActivityType.atlasName
            model.title = w.workoutActivityType.atlasName
        default:
            model.kind = .sport
            model.sport = w.workoutActivityType.atlasName
            model.title = w.workoutActivityType.atlasName
        }
        model.load = ScoreEngine.sessionLoad(durationMin: model.durationSec / 60, rpe: 6)
        return model
    }

    private func quantitySamples(_ id: HKQuantityTypeIdentifier, from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        return try await samples(of: type, from: start, to: end)
    }

    /// Latest HRV per wake-day.
    private func hrvByNightMap(from start: Date, to end: Date) async throws -> [Date: Double] {
        let xs = try await quantitySamples(.heartRateVariabilitySDNN, from: start, to: end)
        var map: [Date: Double] = [:]
        for x in xs {
            let day = Calendar.current.startOfDay(for: x.startDate)
            map[day] = x.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
        }
        return map
    }

    private func rhrByNightMap(from start: Date, to end: Date) async throws -> [Date: Double] {
        let xs = try await quantitySamples(.restingHeartRate, from: start, to: end)
        var map: [Date: Double] = [:]
        for x in xs {
            let day = Calendar.current.startOfDay(for: x.startDate)
            map[day] = x.quantity.doubleValue(for: HKUnit(from: "count/min"))
        }
        return map
    }

    private func stepsByDay(from start: Date, to end: Date) async throws -> [Date: Int] {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsCollectionQuery(
                quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum,
                anchorDate: Calendar.current.startOfDay(for: start), intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, results, error in
                if let error { cont.resume(throwing: error); return }
                var map: [Date: Int] = [:]
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    if let v = stat.sumQuantity()?.doubleValue(for: .count()) {
                        map[Calendar.current.startOfDay(for: stat.startDate)] = Int(v)
                    }
                }
                cont.resume(returning: map)
            }
            store.execute(q)
        }
    }
    #endif
}

#if canImport(HealthKit)
extension HKWorkoutActivityType {
    var atlasName: String {
        switch self {
        case .running: "Run"
        case .walking: "Walk"
        case .cycling: "Ride"
        case .swimming: "Swim"
        case .rowing: "Row"
        case .hiking: "Hike"
        case .elliptical: "Elliptical"
        case .basketball: "Basketball"
        case .soccer: "Soccer"
        case .tennis: "Tennis"
        case .badminton: "Badminton"
        case .volleyball: "Volleyball"
        case .hockey: "Hockey"
        default: "Workout"
        }
    }
}
#endif
