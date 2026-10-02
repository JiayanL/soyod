import Foundation

nonisolated struct PlanPreview: Sendable {
    var targets: MacroTargets
    var split: [PlannedSession]
    var sleepTargetMin: Int
    var milestones: [Milestone]
    var rationale: String
}

/// Everything onboarding collects; AppState.completeOnboarding persists it.
nonisolated struct OnboardingDraft: Sendable {
    var goalKind: GoalKind = .vertical
    var customTitle: String = ""
    var metric: GoalMetric = .verticalJump
    var customUnit: String = ""
    var baseline: Double      // canonical
    var target: Double        // canonical
    var targetDate: Date
    var name: String = ""
    var sex: Sex = .male
    var birthYear: Int
    var heightCm: Double
    var weightKg: Double
    var activity: ActivityLevel = .moderate
    var experience: Experience = .intermediate
    var trainingDaysPerWeek: Int = 4
    var equipment: Equipment = .gym
    var diet: DietStyle = .none
    var allergies: [String] = []
    var fastingEnabled: Bool = false
    var windowOpen: Int = 720     // minutes after midnight
    var windowClose: Int = 1200
    var units: UnitSystem = .imperial
    var tone: CoachTone = .direct
    var healthGranted = false, calendarGranted = false, notificationsGranted = false

    init(now: Date = AppClock.now) {
        let year = Calendar.current.component(.year, from: now)
        birthYear = year - 28
        heightCm = 178
        weightKg = 80
        baseline = goalKind.defaultBaselineTarget.baseline
        target = goalKind.defaultBaselineTarget.target
        targetDate = Calendar.current.date(byAdding: .weekOfYear, value: goalKind.suggestedWeeks, to: now)!
    }

    /// Resets metric/baseline/target/targetDate from goalKind.
    mutating func applyGoalDefaults() {
        metric = goalKind.defaultMetric
        let d = goalKind.defaultBaselineTarget
        baseline = d.baseline
        target = d.target
        targetDate = Calendar.current.date(byAdding: .weekOfYear,
                                           value: goalKind.suggestedWeeks,
                                           to: AppClock.now)!
    }

    var profileInput: ProfileInput {
        ProfileInput(sex: sex, age: Calendar.current.component(.year, from: AppClock.now) - birthYear,
                     heightCm: heightCm, weightKg: weightKg,
                     activityLevel: activity, dietStyle: diet)
    }

    func preview(now: Date = AppClock.now) -> PlanPreview {
        let targets = NutritionEngine.targets(for: profileInput, goal: goalKind)
        let split = ProgramGenerator.weeklySplit(goal: goalKind, daysPerWeek: trainingDaysPerWeek,
                                                 equipment: equipment, experience: experience)
        let sleepTarget = 480
        var cal = Calendar.current
        cal.timeZone = .current
        let snapshot = GoalSnapshot(kind: goalKind,
                                    title: goalKind == .custom ? customTitle : goalKind.title,
                                    metric: metric, customUnit: customUnit.isEmpty ? nil : customUnit,
                                    baseline: baseline, current: baseline, target: target,
                                    startDate: now, targetDate: targetDate,
                                    daysLeft: Int(targetDate.timeIntervalSince(now) / 86400),
                                    projection: Projection(current: baseline, slopePerDay: 0,
                                                           projectedDate: targetDate,
                                                           status: .insufficientData))
        let milestones = ProjectionEngine.milestones(goal: snapshot, measurements: [], now: now, units: units)
        let rationale = rationaleText(targets: targets)
        return PlanPreview(targets: targets, split: split, sleepTargetMin: sleepTarget,
                           milestones: milestones, rationale: rationale)
    }

    private func rationaleText(targets: MacroTargets) -> String {
        let goalPhrase: String
        switch goalKind {
        case .vertical: goalPhrase = "elastic power, so training pairs plyometrics with heavy lower-body strength"
        case .glutes: goalPhrase = "glute growth, so hip thrusts and posterior work anchor the week"
        case .waist, .fatLoss: goalPhrase = "fat loss, so we run a ~20% deficit while keeping protein high"
        case .muscle: goalPhrase = "lean mass, a small surplus with progressive overload"
        case .strength: goalPhrase = "max strength, built around heavy compound work"
        case .run: goalPhrase = "a faster 5K, mostly Zone 2 with one interval day"
        case .custom: goalPhrase = "your goal, balanced for steady progress"
        }
        return "You're training for \(goalPhrase). \(Fmt.kcal(Double(targets.kcal))) kcal/day with \(targets.proteinG) g protein to protect muscle."
    }
}
