import Foundation
import SwiftData
import Observation

enum AppTab: String, Sendable {
    case coach, fuel, train, sleep, progress
}

@Observable
@MainActor
final class AppState {
    let container: ModelContainer
    var modelContext: ModelContext { container.mainContext }

    let health = HealthKitService()
    let calendar = CalendarService()
    let notifications = NotificationService()
    let actions: ActionService

    let launch: LaunchOptions

    var context = CoachContext(now: AppClock.now)
    var directives: [Directive] = []
    var engineStatus = CoachRouter.engineStatus
    var lastImport: ImportSummary?
    var isCoachThinking = false
    var selectedTab: AppTab = .coach
    var needsOnboarding = true
    var pendingRoute: LaunchRoute?

    var profile: UserProfile?
    var goal: Goal?
    var plan: PlanSnapshot?

    private var coach: any CoachAgent = CoachRouter.current()

    init(inMemory: Bool = false, launch: LaunchOptions = LaunchOptions()) {
        self.launch = launch
        let schema = Schema([
            UserProfile.self, Goal.self, Measurement.self, PlanSnapshot.self,
            MealEntry.self, Workout.self, SleepSession.self, DailyMetric.self,
            CoachMessage.self, MemoryItem.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        container = try! ModelContainer(for: schema, configurations: [config])
        actions = ActionService(calendar: calendar, notifications: notifications)
        pendingRoute = launch.screen

        if launch.resetOnboarding {
            resetAll()
        } else if launch.sampleData {
            loadSampleData()
        }
        refresh()
    }

    // MARK: - Context

    /// Rebuilds CoachContext + directives. Call after every mutation.
    func refresh() {
        profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
        goal = try? modelContext.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.isActive })).first
        plan = try? modelContext.fetch(FetchDescriptor<PlanSnapshot>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])).first
        needsOnboarding = !(profile?.onboardingComplete ?? false)

        let isSample = profile?.isSampleData ?? false
        var events = calendar.events(on: AppClock.now, isSampleData: isSample)
        let tomorrowEvents = calendar.events(on: AppClock.now.addingTimeInterval(86400), isSampleData: isSample)
        // Dedupe real+synthetic by id.
        var seen = Set<String>()
        events = (events + tomorrowEvents).filter { seen.insert($0.id).inserted }

        context = ContextBuilder.build(modelContext: modelContext, events: events, now: AppClock.now)
        directives = GamePlanEngine.directives(context: context)
        engineStatus = CoachRouter.engineStatus
    }

    // MARK: - Coach

    func send(_ text: String) async {
        let userMsg = CoachMessage()
        userMsg.role = .user
        userMsg.text = text
        userMsg.date = AppClock.now
        modelContext.insert(userMsg)
        try? modelContext.save()

        isCoachThinking = true
        defer { isCoachThinking = false }

        let history = ((try? modelContext.fetch(FetchDescriptor<CoachMessage>(sortBy: [SortDescriptor(\.date)]))) ?? [])
            .suffix(20).map { ChatTurn(role: $0.role, text: $0.text) }

        let reply: CoachReply
        do {
            reply = try await coach.respond(to: text, history: history, context: context)
        } catch {
            reply = (try? await RuleBasedCoach().respond(to: text, history: history, context: context))
                ?? CoachReply(text: "Something glitched — try that again.")
        }

        // Apply memory writes.
        for m in reply.memoryWrites {
            addMemory(kind: m.kind, text: m.text, dueDate: m.dueDate)
        }
        // Apply logs.
        for log in reply.logs {
            switch log {
            case .meal(let title, let mealType, let items):
                logMeal(title: title, mealType: mealType, items: items, photo: nil, source: .coach, date: AppClock.now)
            case .workout(let kind, let title, let durationMin, let distanceM, let rpe, let sport):
                _ = saveWorkout(WorkoutDraft(kind: kind, title: title, start: AppClock.now,
                                             durationSec: durationMin * 60,
                                             distanceM: distanceM, rpe: rpe, sport: sport))
            }
        }

        let coachMsg = CoachMessage()
        coachMsg.role = .coach
        coachMsg.text = reply.text
        coachMsg.actions = reply.actions
        coachMsg.date = AppClock.now
        modelContext.insert(coachMsg)
        try? modelContext.save()
        refresh()
    }

    @discardableResult
    func perform(_ action: CoachAction, messageID: UUID?) async -> ActionOutcome {
        var outcome: ActionOutcome
        if action.kind == .logMeal {
            // Materialize the meal from params.
            if let json = action.params["itemsJSON"], let data = json.data(using: .utf8),
               let items = try? JSONDecoder().decode([FoodItem].self, from: data) {
                let type = MealType(rawValue: action.params["mealType"] ?? "") ?? Self.defaultMealType(at: AppClock.now)
                logMeal(title: action.params["title"] ?? action.title, mealType: type,
                        items: items, photo: nil, source: .coach, date: AppClock.now)
                outcome = .logged
            } else {
                outcome = .failed("Nothing to log.")
            }
        } else {
            outcome = await actions.perform(action)
        }

        // Update status on the persisted copy (in CoachMessage.actions or a directive).
        var updated = action
        switch outcome {
        case .failed(let reason):
            updated.status = .proposed
            updated.resultNote = reason
        default:
            updated.status = .done
            switch outcome {
            case .addedToCalendar(let d): updated.resultNote = "On your calendar at \(Fmt.clock(d))"
            case .reminderScheduled(let d): updated.resultNote = "Reminder set for \(Fmt.clock(d))"
            case .openedURL: updated.resultNote = "Opened \(action.providerName)"
            case .logged: updated.resultNote = "Logged"
            case .failed: break
            }
        }
        updateActionStatus(updated, messageID: messageID)
        refresh()
        return outcome
    }

    func dismiss(_ action: CoachAction, messageID: UUID?) {
        var updated = action
        updated.status = .dismissed
        updateActionStatus(updated, messageID: messageID)
    }

    private func updateActionStatus(_ action: CoachAction, messageID: UUID?) {
        // Directive match?
        if let i = directives.firstIndex(where: { $0.action?.id == action.id }) {
            directives[i].action = action
        }
        // Scan recent messages for the action id.
        let all = (try? modelContext.fetch(FetchDescriptor<CoachMessage>(sortBy: [SortDescriptor(\.date)]))) ?? []
        for msg in all.reversed() {
            if let messageID, msg.id != messageID { continue }
            if let i = msg.actions.firstIndex(where: { $0.id == action.id }) {
                var actions = msg.actions
                actions[i] = action
                msg.actions = actions
                try? modelContext.save()
                break
            }
        }
    }

    // MARK: - Meals

    func logMeal(title: String, mealType: MealType, items: [FoodItem],
                 photo: Data?, source: MealSource, date: Date) {
        let meal = MealEntry()
        meal.date = date
        meal.mealType = mealType
        meal.title = title
        meal.items = items
        meal.photo = photo
        meal.source = source
        modelContext.insert(meal)
        try? modelContext.save()
        Task { await health.save(meal: meal) }
        refresh()
    }

    func deleteMeal(_ meal: MealEntry) {
        modelContext.delete(meal)
        try? modelContext.save()
        refresh()
    }

    func updateMeal(_ meal: MealEntry) {
        try? modelContext.save()
        Task { await health.save(meal: meal) }
        refresh()
    }

    nonisolated static func defaultMealType(at date: Date) -> MealType {
        let h = Calendar.current.component(.hour, from: date)
        switch h {
        case ..<11: return .breakfast
        case ..<15: return .lunch
        case ..<17: return .snack
        default: return .dinner
        }
    }

    // MARK: - Workouts

    @discardableResult
    func saveWorkout(_ draft: WorkoutDraft) -> WorkoutSaveResult {
        let w = Workout()
        w.date = draft.start
        w.kind = draft.kind
        w.title = draft.title
        w.durationSec = draft.durationSec
        w.distanceM = draft.distanceM
        w.avgHR = draft.avgHR
        w.rpe = draft.rpe
        w.sport = draft.sport
        w.source = .manual

        // PR detection vs history (best e1RM / best weight at reps).
        var prs: [PRRecord] = []
        var logs = draft.exercises
        for li in logs.indices {
            let exId = logs[li].exerciseId
            let prevBest = bestE1RM(exerciseId: exId)
            for si in logs[li].sets.indices where logs[li].sets[si].done {
                let e = logs[li].sets[si].e1RM
                if let prevBest, e > prevBest {
                    logs[li].sets[si].isPR = true
                    prs.append(PRRecord(exerciseName: logs[li].name,
                                        weightKg: logs[li].sets[si].weightKg,
                                        reps: logs[li].sets[si].reps, e1RM: e))
                } else if prevBest == nil, logs[li].sets[si].weightKg > 0 {
                    // First time lifting this exercise with weight — not a PR.
                }
            }
        }
        w.exercises = logs

        // Load.
        let rpe = draft.rpe ?? avgRPE(of: logs) ?? 7
        w.load = ScoreEngine.sessionLoad(durationMin: w.durationSec / 60, rpe: rpe)

        modelContext.insert(w)
        try? modelContext.save()
        Task { await health.save(workout: w) }
        refresh()
        return WorkoutSaveResult(workout: w, prs: prs)
    }

    private func avgRPE(of logs: [ExerciseLog]) -> Double? {
        let rpes = logs.flatMap(\.sets).compactMap(\.rpe)
        return rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count)
    }

    /// Last session's sets for an exercise (inline "PREV").
    func previousSets(exerciseId: String) -> [SetLog] {
        let workouts = (try? modelContext.fetch(FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
        for w in workouts {
            if let ex = w.exercises.first(where: { $0.exerciseId == exerciseId }),
               !ex.sets.isEmpty {
                return ex.sets
            }
        }
        return []
    }

    /// Best historical e1RM for an exercise (excluding `now`'s drafts).
    func bestE1RM(exerciseId: String) -> Double? {
        let workouts = (try? modelContext.fetch(FetchDescriptor<Workout>())) ?? []
        let best = workouts
            .flatMap(\.exercises)
            .filter { $0.exerciseId == exerciseId }
            .flatMap(\.sets)
            .filter(\.done)
            .map(\.e1RM)
            .max()
        return best
    }

    // MARK: - Sleep

    func logSleep(start: Date, end: Date, quality: Int) {
        let s = SleepSession()
        s.start = start
        s.end = end
        s.quality = quality
        s.source = .manual
        s.stages = synthesizedStages(start: start, end: end, quality: quality)
        modelContext.insert(s)
        try? modelContext.save()
        refresh()
    }

    /// Plausible stage structure for a manual log.
    private func synthesizedStages(start: Date, end: Date, quality: Int) -> [SleepStageSegment] {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return [] }
        // awake ~5–20% depending on quality; rem ~22%, deep ~15%, core rest.
        let awakeFrac = [0.20, 0.15, 0.10, 0.07, 0.05][max(0, min(4, quality - 1))]
        var stages: [SleepStageSegment] = []
        var t = start
        func seg(_ stage: SleepStage, _ frac: Double) {
            let d = total * frac
            stages.append(SleepStageSegment(stage: stage, start: t, end: t.addingTimeInterval(d)))
            t = t.addingTimeInterval(d)
        }
        // Interleave blocks for a plausible hypnogram.
        seg(.core, 0.20)
        seg(.deep, 0.09)
        seg(.core, 0.12)
        seg(.rem, 0.10)
        seg(.awake, awakeFrac / 2)
        seg(.core, 0.15)
        seg(.deep, 0.06)
        seg(.rem, 0.12)
        seg(.awake, awakeFrac / 2)
        seg(.core, 0.16 - awakeFrac)
        seg(.rem, 0.0 + max(0, 1 - stages.reduce(0) { $0 + $1.minutes } / (total / 60)))
        // Fix: pad any leftover to core.
        let covered = stages.reduce(0) { $0 + $1.minutes }
        let remaining = total / 60 - covered
        if remaining > 1 {
            stages.append(SleepStageSegment(stage: .core, start: t, end: end))
        }
        return stages.filter { $0.minutes > 0 }
    }

    // MARK: - Measurements

    func addMeasurement(value canonical: Double, date: Date) {
        guard let metric = goal?.metric else { return }
        let m = Measurement()
        m.date = date
        m.metric = metric
        m.value = canonical
        modelContext.insert(m)
        try? modelContext.save()
        refresh()
    }

    func deleteMeasurement(_ m: Measurement) {
        modelContext.delete(m)
        try? modelContext.save()
        refresh()
    }

    // MARK: - Memories

    func addMemory(kind: MemoryKind, text: String, dueDate: Date?) {
        let m = MemoryItem()
        m.kind = kind
        m.text = text
        m.dueDate = dueDate
        m.createdAt = AppClock.now
        modelContext.insert(m)
        try? modelContext.save()
    }

    func deleteMemory(_ item: MemoryItem) {
        modelContext.delete(item)
        try? modelContext.save()
        refresh()
    }

    func updateMemory(_ item: MemoryItem) {
        try? modelContext.save()
        refresh()
    }

    // MARK: - Onboarding / sample data

    func completeOnboarding(_ draft: OnboardingDraft) {
        let p = profile ?? UserProfile()
        p.name = draft.name
        p.sex = draft.sex
        p.birthYear = draft.birthYear
        p.heightCm = draft.heightCm
        p.weightKg = draft.weightKg
        p.activityLevel = draft.activity
        p.experience = draft.experience
        p.trainingDaysPerWeek = draft.trainingDaysPerWeek
        p.equipment = draft.equipment
        p.dietStyle = draft.diet
        p.allergies = draft.allergies
        p.fastingStartMinutes = draft.fastingEnabled ? draft.windowOpen : nil
        p.fastingEndMinutes = draft.fastingEnabled ? draft.windowClose : nil
        p.unitSystem = draft.units
        p.coachTone = draft.tone
        p.onboardingComplete = true
        p.isSampleData = false
        if profile == nil { modelContext.insert(p) }

        let g = Goal()
        g.kind = draft.goalKind
        g.title = draft.goalKind == .custom ? draft.customTitle : draft.goalKind.title
        g.metric = draft.metric
        g.customUnit = draft.customUnit.isEmpty ? nil : draft.customUnit
        g.baseline = draft.baseline
        g.target = draft.target
        g.startDate = AppClock.now
        g.targetDate = draft.targetDate
        g.isActive = true
        modelContext.insert(g)

        let baselineMeasurement = Measurement()
        baselineMeasurement.date = AppClock.now
        baselineMeasurement.metric = draft.metric
        baselineMeasurement.value = draft.baseline
        modelContext.insert(baselineMeasurement)

        let preview = draft.preview()
        let snapshot = PlanSnapshot()
        snapshot.createdAt = AppClock.now
        snapshot.kcalTarget = preview.targets.kcal
        snapshot.proteinG = preview.targets.proteinG
        snapshot.carbsG = preview.targets.carbsG
        snapshot.fatG = preview.targets.fatG
        snapshot.sleepTargetMin = preview.sleepTargetMin
        snapshot.weeklySplit = preview.split
        snapshot.rationale = preview.rationale
        modelContext.insert(snapshot)

        try? modelContext.save()
        refresh()
    }

    func loadSampleData() {
        SampleDataSeeder().seed(into: modelContext, now: AppClock.now)
        try? modelContext.save()
        refresh()
    }

    func resetAll() {
        func wipe<T: PersistentModel>(_ type: T.Type) {
            if let objects = try? modelContext.fetch(FetchDescriptor<T>()) {
                for o in objects { modelContext.delete(o) }
            }
        }
        wipe(UserProfile.self); wipe(Goal.self); wipe(Measurement.self)
        wipe(PlanSnapshot.self); wipe(MealEntry.self); wipe(Workout.self)
        wipe(SleepSession.self); wipe(DailyMetric.self); wipe(CoachMessage.self)
        wipe(MemoryItem.self)
        try? modelContext.save()
        refresh()
    }

    /// Wipes the store → needsOnboarding = true.
    func resetAllData() {
        resetAll()
    }

    // MARK: - Health import

    @discardableResult
    func importHealth() async -> ImportSummary? {
        guard health.status == .requested else { return nil }
        let summary = await health.importRecent(into: modelContext, days: 30)
        lastImport = summary
        refresh()
        return summary
    }

    // MARK: - Settings mutations

    func setUnits(_ units: UnitSystem) {
        profile?.unitSystem = units
        try? modelContext.save()
        refresh()
    }

    func setTone(_ tone: CoachTone) {
        profile?.coachTone = tone
        try? modelContext.save()
        refresh()
    }

    /// Eating window in minutes since midnight; nil disables it.
    func setEatingWindow(open: Int?, close: Int?) {
        profile?.fastingStartMinutes = open
        profile?.fastingEndMinutes = close
        try? modelContext.save()
        refresh()
    }

    func updateEatingWindow(open: Int?, close: Int?) {
        setEatingWindow(open: open, close: close)
    }

    /// Persist mutations made directly to `profile`, recompute plan/targets/context.
    func saveProfile() {
        try? modelContext.save()
        refresh()
    }

    // MARK: - Remote LLM settings

    var remoteLLMConfigured: Bool {
        KeychainStore.string(for: "atlas.remoteLLMKey") != nil
    }

    func setRemoteLLMKey(_ key: String?) {
        if let key, !key.isEmpty {
            KeychainStore.set(key, for: "atlas.remoteLLMKey")
        } else {
            KeychainStore.delete("atlas.remoteLLMKey")
        }
        coach = CoachRouter.current()
        engineStatus = CoachRouter.engineStatus
    }

    func updateProfile(name: String? = nil, sex: Sex? = nil, birthYear: Int? = nil,
                       heightCm: Double? = nil, weightKg: Double? = nil,
                       activity: ActivityLevel? = nil, experience: Experience? = nil,
                       trainingDaysPerWeek: Int? = nil, equipment: Equipment? = nil,
                       diet: DietStyle? = nil, allergies: [String]? = nil) {
        guard let p = profile else { return }
        if let name { p.name = name }
        if let sex { p.sex = sex }
        if let birthYear { p.birthYear = birthYear }
        if let heightCm { p.heightCm = heightCm }
        if let weightKg { p.weightKg = weightKg }
        if let activity { p.activityLevel = activity }
        if let experience { p.experience = experience }
        if let trainingDaysPerWeek { p.trainingDaysPerWeek = trainingDaysPerWeek }
        if let equipment { p.equipment = equipment }
        if let diet { p.dietStyle = diet }
        if let allergies { p.allergies = allergies }
        try? modelContext.save()
        refresh()
    }

    func updateGoal(baseline: Double? = nil, target: Double? = nil,
                    targetDate: Date? = nil, metric: GoalMetric? = nil) {
        guard let g = goal else { return }
        if let baseline { g.baseline = baseline }
        if let target { g.target = target }
        if let targetDate { g.targetDate = targetDate }
        if let metric { g.metric = metric }
        try? modelContext.save()
        refresh()
    }

    // MARK: - Suggested prompts

    var suggestedPrompts: [String] {
        var out: [String] = []
        if (context.lastSleep?.score ?? 100) < 60 {
            out.append("I slept badly — what should I change?")
        }
        if context.events.contains(where: { $0.title.lowercased().contains("dinner") || $0.location != nil }) {
            out.append("I have a work dinner tonight")
        }
        if let s = context.todaySession {
            out.append("Talk me through \(s.title)")
        }
        out.append("Order me lunch that fits my macros")
        out.append("Am I on track?")
        return Array(out.prefix(4))
    }
}
