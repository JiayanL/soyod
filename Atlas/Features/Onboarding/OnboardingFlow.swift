import SwiftUI

enum OnbStep: Int, CaseIterable {
    case welcome, goal, baseline, about, fuel, connect, plan

    init?(route: LaunchRoute?) {
        switch route {
        case .onbWelcome: self = .welcome
        case .onbGoal: self = .goal
        case .onbBaseline: self = .baseline
        case .onbAbout: self = .about
        case .onbFuel: self = .fuel
        case .onbConnect: self = .connect
        case .onbPlan: self = .plan
        default: return nil
        }
    }
}

struct OnboardingFlow: View {
    @Environment(AppState.self) private var app
    @State private var step: OnbStep
    @State private var forward = true
    @State private var draft: OnboardingDraft

    init(start: OnbStep = .welcome) {
        _step = State(initialValue: start)
        var d = OnboardingDraft()
        if start.rawValue > OnbStep.about.rawValue, d.name.isEmpty { d.name = "Marcus" }
        _draft = State(initialValue: d)
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                header
                    .gutter()
                    .padding(.top, Theme.Space.xs)
            }
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background(alignment: .top) {
            if step == .welcome {
                AtmosphereBackground(tint: Theme.Palette.accentFill, height: 560)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .atlasScreenBackground()
        .onChange(of: app.pendingRoute) { _, route in
            if let s = OnbStep(route: route) { step = s; app.pendingRoute = nil }
        }
        .onAppear { if OnbStep(route: app.pendingRoute) != nil { app.pendingRoute = nil } }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.s) {
            IconButton(symbol: "chevron.left", label: "Back", filled: false) { go(-1) }
            StepProgress(step: step.rawValue, total: OnbStep.allCases.count - 1)
            Text("\(step.rawValue)/\(OnbStep.allCases.count - 1)")
                .textStyle(.footnote)
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(minWidth: Theme.Size.minTap)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            WelcomeStep(onStart: { go(1) }, onSample: { app.loadSampleData() })
        case .goal:
            GoalStep(draft: $draft) { go(1) }
        case .baseline:
            BaselineStep(draft: $draft) { go(1) }
        case .about:
            AboutStep(draft: $draft) { go(1) }
        case .fuel:
            FuelStep(draft: $draft) { go(1) }
        case .connect:
            ConnectStep(draft: $draft) { go(1) }
        case .plan:
            PlanRevealStep(draft: draft) { app.completeOnboarding(draft) }
        }
    }

    private func go(_ delta: Int) {
        guard let next = OnbStep(rawValue: step.rawValue + delta) else { return }
        forward = delta > 0
        hideKeyboard()
        withAnimation(Theme.Motion.standard) { step = next }
    }
}

/// Common layout for a question step: serif title, scrolling body, pinned CTA.
struct OnbPage<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var cta: String = "Continue"
    var ctaEnabled = true
    var ctaIdentifier = "onbContinue"
    let onContinue: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(title)
                        .textStyle(.displayS)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .textStyle(.body)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content()
            }
            .gutter()
            .padding(.top, Theme.Space.xl)
            .padding(.bottom, Theme.Space.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(cta, action: onContinue)
                .buttonStyle(.atlasPrimary)
                .disabled(!ctaEnabled)
                .accessibilityIdentifier(ctaIdentifier)
                .gutter()
                .padding(.top, Theme.Space.s)
                .padding(.bottom, Theme.Space.xs)
                .bottomBarScrim()
        }
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let onStart: () -> Void
    let onSample: () -> Void
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                AtlasMark(size: 56, glow: true)
                    .padding(.top, Theme.Space.huge)
                Spacer(minLength: Theme.Space.xxl)
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    MicroLabel("Atlas · Your fitness concierge", color: Theme.Palette.accent)
                    Text("One goal.\nEvery meal, rep and night of sleep pointed at it.")
                        .textStyle(.display)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Atlas reads your sleep, training, food and calendar, then tells you exactly what to do today — and handles the bookings.")
                        .textStyle(.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : Theme.Space.l)
                Spacer(minLength: Theme.Space.xxl)
                VStack(spacing: Theme.Space.xs) {
                    Button("Set my goal", action: onStart)
                        .buttonStyle(.atlasHero)
                        .accessibilityIdentifier("onbStart")
                    Button("Explore with sample data", action: onSample)
                        .buttonStyle(SecondaryButtonStyle(fullWidth: true, compact: false))
                        .accessibilityIdentifier("onbSample")
                }
                .padding(.bottom, Theme.Space.xs)
            }
            .gutter()
        }
        .onAppear { withAnimation(Theme.Motion.gentle.delay(0.15)) { appeared = true } }
    }
}

// MARK: - Goal

private struct GoalStep: View {
    @Binding var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        OnbPage(title: "What are we working toward?", subtitle: "Pick one outcome. Atlas builds food, training and sleep around it.", onContinue: onContinue) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.s), GridItem(.flexible(), spacing: Theme.Space.s)], spacing: Theme.Space.s) {
                ForEach(GoalKind.allCases) { kind in
                    GoalCard(kind: kind, selected: draft.goalKind == kind) {
                        withAnimation(Theme.Motion.snappy) {
                            draft.goalKind = kind
                            draft.applyGoalDefaults()
                        }
                    }
                }
            }
        }
    }
}

private struct GoalCard: View {
    let kind: GoalKind
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(alignment: .top) {
                    Image(systemName: kind.symbol)
                        .icon(Theme.Icon.hero, weight: .medium)
                        .foregroundStyle(selected ? Theme.Palette.onAccent : Theme.Palette.textPrimary)
                        .frame(height: Theme.Icon.art)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .icon(Theme.Icon.large, weight: .regular)
                            .foregroundStyle(Theme.Palette.onAccent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Spacer(minLength: Theme.Space.s)
                Text(kind.title)
                    .textStyle(.headline)
                    .foregroundStyle(selected ? Theme.Palette.onAccent : Theme.Palette.textPrimary)
                Text(kind.subtitle)
                    .textStyle(.footnote)
                    .foregroundStyle(selected ? Theme.Palette.onAccent.opacity(0.7) : Theme.Palette.textSecondary)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(Theme.Space.m)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .background(selected ? Theme.Palette.accentFill : Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Stroke.hairline)
            }
            .scaleEffect(selected ? 1.0 : 0.98)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title). \(kind.subtitle)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("goal-\(kind.rawValue)")
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Baseline

private struct BaselineStep: View {
    @Binding var draft: OnboardingDraft
    let onContinue: () -> Void

    private var dimension: MetricDimension { draft.metric.dimension }
    private var unit: String { UnitConvert.unit(dimension, units: draft.units, custom: draft.customUnit) }

    private var metricOptions: [GoalMetric] {
        switch draft.goalKind {
        case .strength: [.squat1RM, .bench1RM, .deadlift1RM]
        case .run: [.fiveK, .tenK]
        case .muscle, .fatLoss: [.bodyWeight, .waist]
        default: []
        }
    }

    static func defaults(for metric: GoalMetric, kind: GoalKind) -> (Double, Double) {
        if metric == kind.defaultMetric { return (kind.defaultBaselineTarget.baseline, kind.defaultBaselineTarget.target) }
        switch metric {
        case .squat1RM: return (102.1, 129.3)
        case .bench1RM: return (84.0, 102.1)
        case .deadlift1RM: return (140.6, 183.7)
        case .fiveK: return (1530, 1200)
        case .tenK: return (3300, 2700)
        case .waist: return (91.4, 83.8)
        case .bodyWeight: return kind == .muscle ? (72.6, 79.4) : (90.7, 81.6)
        default: return (kind.defaultBaselineTarget.baseline, kind.defaultBaselineTarget.target)
        }
    }

    private var valid: Bool {
        let customOK = draft.goalKind != .custom || !draft.customTitle.trimmingCharacters(in: .whitespaces).isEmpty
        return customOK && draft.baseline != draft.target && draft.targetDate > AppClock.now
    }

    private var weeks: Int {
        max(1, Calendar.current.dateComponents([.day], from: AppClock.now, to: draft.targetDate).day.map { Int(($0 + 3) / 7) } ?? 1)
    }

    var body: some View {
        OnbPage(
            title: draft.goalKind == .custom ? "Name your goal" : "Where are you now?",
            subtitle: "Your starting point and target. Rough numbers are fine — we'll re-test along the way.",
            ctaEnabled: valid,
            onContinue: onContinue
        ) {
            if draft.goalKind == .custom {
                VStack(spacing: Theme.Space.s) {
                    TextField("e.g. Hold a 2-minute plank", text: $draft.customTitle)
                        .textStyle(.headline)
                        .padding(Theme.Space.m)
                        .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                        .accessibilityIdentifier("customTitle")
                    TextField("Unit (e.g. sec, reps, ″)", text: $draft.customUnit)
                        .textStyle(.body)
                        .padding(Theme.Space.m)
                        .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                        .accessibilityIdentifier("customUnit")
                }
            }
            if !metricOptions.isEmpty {
                FormGroup(title: "Measure it by") {
                    ChipPicker(options: metricOptions.map { ($0, $0.title) }, isSelected: { $0 == draft.metric }) { m in
                        draft.metric = m
                        let d = Self.defaults(for: m, kind: draft.goalKind)
                        draft.baseline = d.0
                        draft.target = d.1
                    }
                }
            }
            HStack(spacing: Theme.Space.s) {
                valueField("Today", value: $draft.baseline, id: "baseline")
                Image(systemName: "arrow.right")
                    .icon(Theme.Icon.small, weight: .bold)
                    .foregroundStyle(Theme.Palette.textTertiary)
                valueField("Target", value: $draft.target, id: "target")
            }
            FormGroup(title: "By") {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    ChipPicker(options: [8, 12, 16, 20, 26].map { ($0, "\($0) weeks") }, isSelected: { $0 == weeks }) { w in
                        draft.targetDate = Calendar.current.date(byAdding: .day, value: w * 7, to: AppClock.now) ?? draft.targetDate
                    }
                    DatePicker("Target date", selection: $draft.targetDate, in: AppClock.now.addingTimeInterval(86_400 * 7)..., displayedComponents: .date)
                        .textStyle(.body)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.vertical, Theme.Space.xs)
                        .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                }
            }
            if valid {
                feasibility
            }
        }
    }

    @ViewBuilder
    private func valueField(_ label: String, value: Binding<Double>, id: String) -> some View {
        if dimension == .time {
            DurationField(label: label, seconds: value)
        } else {
            NumberField(
                label: label,
                value: Binding(
                    get: { (UnitConvert.display(value.wrappedValue, dimension: dimension, units: draft.units) * 10).rounded() / 10 },
                    set: { value.wrappedValue = UnitConvert.canonical($0, dimension: dimension, units: draft.units) }
                ),
                unit: unit,
                identifier: id
            )
        }
    }

    private var feasibility: some View {
        let delta = abs(draft.target - draft.baseline)
        let pct = draft.baseline != 0 ? delta / abs(draft.baseline) / Double(weeks) * 100 : 0
        let (word, color): (String, Color) = pct > 3 ? ("Ambitious", Theme.Palette.fuel) : (pct > 1.2 ? ("Challenging but realistic", Theme.Palette.accent) : ("Very doable", Theme.Palette.recovery))
        return HStack(alignment: .top, spacing: Theme.Space.s) {
            IconDisk(symbol: "scope", color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(word).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                Text("\(weeks) weeks to go from \(display(draft.baseline)) to \(display(draft.target)). Atlas will check in every 4 weeks.")
                    .textStyle(.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .atlasCard()
    }

    private func display(_ canonical: Double) -> String {
        if dimension == .time {
            let s = Int(canonical)
            return String(format: "%d:%02d", s / 60, s % 60)
        }
        let v = UnitConvert.display(canonical, dimension: dimension, units: draft.units)
        let u = unit == "in" ? "″" : " \(unit)"
        return UnitConvert.number(v) + u
    }
}

// MARK: - About

private struct AboutStep: View {
    @Binding var draft: OnboardingDraft
    let onContinue: () -> Void

    private var age: Binding<Double> {
        Binding(
            get: { Double(Calendar.current.component(.year, from: AppClock.now) - draft.birthYear) },
            set: { draft.birthYear = Calendar.current.component(.year, from: AppClock.now) - Int($0) }
        )
    }

    var body: some View {
        OnbPage(title: "A little about you", subtitle: "Used for calorie, protein and recovery math. Never shared.", onContinue: onContinue) {
            TextField("First name", text: $draft.name)
                .textStyle(.headline)
                .textContentType(.givenName)
                .padding(Theme.Space.m)
                .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                .accessibilityIdentifier("name")

            SegmentedPills(options: UnitSystem.allCases.map { ($0, $0.title) }, selection: $draft.units)

            SegmentedPills(options: Sex.allCases.map { ($0, $0.title) }, selection: $draft.sex)

            HStack(spacing: Theme.Space.s) {
                NumberField(label: "Age", value: age, unit: "yrs", decimals: 0)
                NumberField(
                    label: "Weight",
                    value: Binding(
                        get: { UnitConvert.weightDisplay(kg: draft.weightKg, units: draft.units).rounded() },
                        set: { draft.weightKg = UnitConvert.weightCanonical($0, units: draft.units) }
                    ),
                    unit: UnitConvert.weightUnit(draft.units),
                    decimals: 0
                )
            }
            heightField

            FormGroup(title: "Activity") {
                VStack(spacing: Theme.Space.xs) {
                    ForEach(ActivityLevel.allCases) { level in
                        OptionRow(title: level.title, subtitle: level.subtitle, selected: draft.activity == level) {
                            draft.activity = level
                        }
                    }
                }
            }
            FormGroup(title: "Training experience") {
                SegmentedPills(options: Experience.allCases.map { ($0, $0.title) }, selection: $draft.experience)
            }
            FormGroup(title: "Days per week") {
                SegmentedPills(options: (2...6).map { ($0, "\($0)") }, selection: $draft.trainingDaysPerWeek)
            }
            FormGroup(title: "Equipment") {
                SegmentedPills(options: Equipment.allCases.map { ($0, $0.title) }, selection: $draft.equipment)
            }
        }
    }

    @ViewBuilder
    private var heightField: some View {
        if draft.units == .imperial {
            let totalIn = (draft.heightCm / UnitConvert.cmPerInch).rounded()
            HStack(spacing: Theme.Space.s) {
                NumberField(
                    label: "Height",
                    value: Binding(
                        get: { (totalIn / 12).rounded(.down) },
                        set: { draft.heightCm = ($0 * 12 + totalIn.truncatingRemainder(dividingBy: 12)) * UnitConvert.cmPerInch }
                    ),
                    unit: "ft", decimals: 0
                )
                NumberField(
                    label: " ",
                    value: Binding(
                        get: { totalIn.truncatingRemainder(dividingBy: 12) },
                        set: { draft.heightCm = ((totalIn / 12).rounded(.down) * 12 + min(11, max(0, $0))) * UnitConvert.cmPerInch }
                    ),
                    unit: "in", decimals: 0
                )
            }
        } else {
            NumberField(label: "Height", value: $draft.heightCm, unit: "cm", decimals: 0)
        }
    }
}

// MARK: - Fuel

private struct FuelStep: View {
    @Binding var draft: OnboardingDraft
    let onContinue: () -> Void

    private let allergyOptions = ["Peanuts", "Tree nuts", "Dairy", "Gluten", "Shellfish", "Eggs", "Soy"]

    var body: some View {
        OnbPage(title: "How do you like to eat?", subtitle: "Atlas plans meals and restaurant orders around this.", onContinue: onContinue) {
            FormGroup(title: "Diet") {
                ChipPicker(options: DietStyle.allCases.map { ($0, $0.title) }, isSelected: { $0 == draft.diet }) { draft.diet = $0 }
            }
            FormGroup(title: "Avoid") {
                ChipPicker(options: allergyOptions.map { ($0, $0) }, isSelected: { draft.allergies.contains($0) }) { a in
                    if let i = draft.allergies.firstIndex(of: a) { draft.allergies.remove(at: i) } else { draft.allergies.append(a) }
                }
            }
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Toggle(isOn: $draft.fastingEnabled.animation(Theme.Motion.standard)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Eating window").textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                        Text("Time-restricted eating, e.g. 16:8").textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .tint(Theme.Palette.accentFill)
                .accessibilityIdentifier("fastingToggle")
                if draft.fastingEnabled {
                    HStack {
                        DatePicker("Opens", selection: minutesBinding(\.windowOpen), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Image(systemName: "arrow.right").icon(Theme.Icon.small).foregroundStyle(Theme.Palette.textTertiary)
                        DatePicker("Closes", selection: minutesBinding(\.windowClose), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Spacer()
                        Text(windowLength)
                            .textStyle(.metricS)
                            .foregroundStyle(Theme.Palette.fuel)
                    }
                    EatingWindowBar(openMinutes: draft.windowOpen, closeMinutes: draft.windowClose, nowMinutes: UnitConvert.timeToMinutes(AppClock.now))
                        .transition(.opacity)
                }
            }
            .atlasCard()
        }
    }

    private var windowLength: String {
        let len = (draft.windowClose - draft.windowOpen + 1440) % 1440
        return "\(24 - len / 60):\(len / 60)"
    }

    private func minutesBinding(_ key: WritableKeyPath<OnboardingDraft, Int>) -> Binding<Date> {
        Binding(
            get: { UnitConvert.minutesToTime(draft[keyPath: key], on: AppClock.now) },
            set: { draft[keyPath: key] = UnitConvert.timeToMinutes($0) }
        )
    }
}

// MARK: - Connect

private struct ConnectStep: View {
    @Binding var draft: OnboardingDraft
    let onContinue: () -> Void
    @Environment(AppState.self) private var app
    @State private var asked: Set<String> = []

    var body: some View {
        OnbPage(
            title: "Connect your context",
            subtitle: "The more Atlas sees, the sharper today's plan. Everything works without these too.",
            cta: asked.isEmpty ? "Not now" : "Continue",
            onContinue: onContinue
        ) {
            VStack(spacing: Theme.Space.s) {
                row(id: "health", symbol: "heart.fill", color: Theme.Palette.train, title: "Apple Health",
                    detail: "Sleep stages, HRV, resting HR, workouts, steps and weight.", granted: draft.healthGranted) {
                    draft.healthGranted = await app.health.requestAuthorization()
                }
                row(id: "calendar", symbol: "calendar", color: Theme.Palette.fuel, title: "Calendar",
                    detail: "Plan meals around dinners and flights. Add workouts to free slots.", granted: draft.calendarGranted) {
                    draft.calendarGranted = await app.calendar.requestAccess()
                }
                row(id: "notifications", symbol: "bell.fill", color: Theme.Palette.sleep, title: "Reminders",
                    detail: "Wind-down, eating window and workout nudges.", granted: draft.notificationsGranted) {
                    draft.notificationsGranted = await app.notifications.requestAuthorization()
                }
            }
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: "lock.fill").icon(Theme.Icon.micro)
                Text("Your data stays on this iPhone.")
                    .textStyle(.footnote)
            }
            .foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    private func row(id: String, symbol: String, color: Color, title: String, detail: String, granted: Bool, request: @escaping () async -> Void) -> some View {
        HStack(alignment: .center, spacing: Theme.Space.s) {
            IconDisk(symbol: symbol, color: color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                Text(detail).textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Space.xs)
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .icon(Theme.Icon.large, weight: .regular)
                    .foregroundStyle(Theme.Palette.recovery)
                    .accessibilityLabel("\(title) connected")
            } else if asked.contains(id) {
                Text("Off").textStyle(.footnote).foregroundStyle(Theme.Palette.textTertiary)
            } else {
                Button("Connect") {
                    Task {
                        await request()
                        asked.insert(id)
                    }
                }
                .buttonStyle(.atlasPrimaryCompact)
                .accessibilityIdentifier("connect-\(id)")
            }
        }
        .atlasCard()
    }
}
