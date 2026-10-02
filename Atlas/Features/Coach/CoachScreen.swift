import SwiftUI
import SwiftData

struct CoachScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Query(sort: \CoachMessage.date, order: .reverse) private var messages: [CoachMessage]

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.coachPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.section) {
                    CoachHeader()
                    PillarRingsRow()
                    GamePlanCard()
                    ActionCarousel()
                    WhyTodayCard()
                    ConversationPreview(last: messages.first(where: { $0.role == .coach }))
                }
                .padding(.top, Theme.Space.xs)
                .padding(.bottom, Theme.Space.xxxl)
            }
            .background(alignment: .top) {
                AtmosphereBackground(tint: atmosphereTint)
                    .ignoresSafeArea()
            }
            .atlasScreenBackground()
            .safeAreaInset(edge: .bottom) {
                TalkToAtlasBar { router.openChat() }
                    .gutter()
                    .padding(.bottom, Theme.Space.xs)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AtlasMark(size: 26)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        router.sheet = .memory
                    } label: {
                        Image(systemName: "brain.head.profile").icon(Theme.Icon.regular)
                    }
                    .accessibilityLabel("What Atlas remembers")
                    QuickLogToolbarButton()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: CoachDestination.self) { dest in
                switch dest {
                case .chat: ChatView()
                }
            }
            .refreshable { app.refresh() }
        }
    }

    private var atmosphereTint: Color {
        guard let r = app.context.recoveryScore else { return Theme.Palette.accentFill }
        return Theme.Palette.score(r)
    }
}

// MARK: - Header

private struct CoachHeader: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let ctx = app.context
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                MicroLabel(ctx.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                Text(greeting(ctx))
                    .textStyle(.display)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(headline(ctx))
                    .textStyle(.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let goal = ctx.goal {
                Button {
                    app.selectedTab = .progress
                } label: {
                    StatusChip(text: goalChipText(goal, units: ctx.units), dot: statusColor(goal.projection.status), showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goalChip")
            }
        }
        .gutter()
    }

    private func greeting(_ ctx: CoachContext) -> String {
        let hour = Calendar.current.component(.hour, from: ctx.now)
        let part = hour < 5 ? "Good evening" : hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        return ctx.userName.isEmpty ? part : "\(part), \(ctx.userName)"
    }

    private func headline(_ ctx: CoachContext) -> String {
        if let r = ctx.recoveryScore, let sleep = ctx.lastSleep {
            if r < 50 {
                return "\(Fmt.duration(minutes: sleep.asleepMin)) of sleep and recovery at \(r)%. Today we protect your legs and bank sleep."
            } else if r >= 75 {
                return "Recovery \(r)%. You're primed — today is a day to push."
            }
            return "Recovery \(r)%. Solid enough to train with intent."
        }
        if let session = ctx.todaySession { return "Today: \(session.title). Here's how to nail it." }
        return "Here's your plan for today."
    }

    private func goalChipText(_ g: GoalSnapshot, units: UnitSystem) -> String {
        let name: String
        switch g.metric {
        case .verticalJump: name = "Vertical"
        case .custom: name = g.title
        default: name = g.metric.title
        }
        let current = Fmt.metric(g.current, metric: g.metric, units: units, customUnit: g.customUnit)
        let target = Fmt.metric(g.target, metric: g.metric, units: units, customUnit: g.customUnit)
        return "\(name) \(current) → \(target) · \(g.daysLeft)d · \(g.projection.status.title)"
    }

    private func statusColor(_ s: ProjectionStatus) -> Color {
        switch s {
        case .ahead, .onTrack, .reached: Theme.Palette.recovery
        case .behind: Theme.Palette.fuel
        case .insufficientData: Theme.Palette.textTertiary
        }
    }
}

// MARK: - Rings

struct PillarRingsRow: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let ctx = app.context
        let fuelPct = ctx.targets.kcal > 0 ? ctx.eaten.kcal / Double(ctx.targets.kcal) : 0
        HStack(spacing: 0) {
            ring(label: "Recovery", value: ctx.recoveryScore, color: ctx.recoveryScore.map(Theme.Palette.score) ?? Theme.Palette.recovery, tab: .sleep)
            ring(label: "Sleep", value: ctx.lastSleep?.score, color: Theme.Palette.sleep, tab: .sleep)
            Button { app.selectedTab = .fuel } label: {
                PillarRing(label: "Fuel", valueText: "\(Int((fuelPct * 100).rounded()))", progress: fuelPct, color: Theme.Palette.fuel)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .gutter()
    }

    private func ring(label: String, value: Int?, color: Color, tab: AppTab) -> some View {
        Button { app.selectedTab = tab } label: {
            PillarRing(label: label, valueText: value.map(String.init) ?? "–", unit: value == nil ? "" : "%", progress: Double(value ?? 0) / 100, color: color)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Game plan

private struct GamePlanCard: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's Game Plan")
                    .textStyle(.title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(app.directives.count) moves")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            if app.directives.isEmpty {
                EmptyStateView(symbol: "checklist", title: "Nothing urgent", message: "Log a meal or a workout and Atlas will tune today's plan.")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(app.directives.enumerated()), id: \.element.id) { index, directive in
                        DirectiveRow(
                            index: index + 1,
                            symbol: directive.pillar.symbol,
                            color: directive.pillar.color,
                            title: directive.title,
                            detail: directive.detail
                        )
                        .padding(.vertical, Theme.Space.s)
                        if index < app.directives.count - 1 {
                            Hairline(leading: Theme.Size.directiveIcon + Theme.Space.s)
                        }
                    }
                }
            }
        }
        .atlasCard(padding: Theme.Space.hero)
        .gutter()
        .accessibilityIdentifier("gamePlan")
    }
}

extension Pillar {
    var color: Color {
        switch self {
        case .goal: Theme.Palette.accent
        case .fuel: Theme.Palette.fuel
        case .train: Theme.Palette.train
        case .sleep: Theme.Palette.sleep
        case .recovery: Theme.Palette.recovery
        }
    }
}

// MARK: - Actions

private struct ActionCarousel: View {
    @Environment(AppState.self) private var app

    private var actions: [CoachAction] {
        app.directives.compactMap(\.action).filter { $0.status != .dismissed }
    }

    var body: some View {
        if !actions.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(title: "Atlas can handle it")
                    .gutter()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Theme.Space.s) {
                        ForEach(actions) { action in
                            CoachActionCard(action: action, messageID: nil)
                                .containerRelativeFrame(.horizontal) { w, _ in w * 0.82 }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, Theme.Space.gutter, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

/// ActionCardView bound to AppState.perform.
struct CoachActionCard: View {
    let action: CoachAction
    let messageID: UUID?
    @Environment(AppState.self) private var app
    @State private var working = false

    var body: some View {
        ActionCardView(
            symbol: action.symbol,
            provider: action.providerName,
            title: action.title,
            subtitle: action.subtitle,
            details: details,
            primaryTitle: action.primaryLabel,
            resultNote: action.resultNote,
            phase: working ? .working : phase,
            onPrimary: {
                working = true
                Task {
                    _ = await app.perform(action, messageID: messageID)
                    working = false
                }
            },
            onDismiss: { app.dismiss(action, messageID: messageID) }
        )
        .accessibilityIdentifier("actionCard-\(action.kind.rawValue)")
    }

    private var phase: ActionCardView.Phase {
        switch action.status {
        case .proposed: .proposed
        case .inProgress: .working
        case .done: .done
        case .dismissed: .dismissed
        }
    }

    private var details: [String] {
        let raw = action.params["orderGuide"] ?? action.params["suggestion"] ?? ""
        return raw.split(separator: "\n").map(String.init).prefix(3).map { $0 }
    }
}

// MARK: - Insight

private struct WhyTodayCard: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        let ctx = app.context
        InsightCard(
            eyebrow: "Why today looks like this",
            headline: headline(ctx),
            message: message(ctx),
            linkTitle: "Ask Atlas why",
            action: { router.openChat(prefill: "Why does today's plan look like this?") }
        )
        .gutter()
    }

    private func headline(_ ctx: CoachContext) -> String {
        if let delta = ctx.hrvDeltaPct, delta < -10 { return "Your nervous system is asking for a lighter day." }
        if ctx.load.status == "High" { return "Training load is running hot." }
        return "You're recovered and fueled to train."
    }

    private func message(_ ctx: CoachContext) -> String {
        var parts: [String] = []
        if let s = ctx.lastSleep {
            parts.append("You slept \(Fmt.duration(minutes: s.asleepMin)) against a \(Fmt.duration(minutes: ctx.sleepNeedMin)) need.")
        }
        if let d = ctx.hrvDeltaPct, let hrv = ctx.lastSleep?.hrvMs {
            parts.append("HRV is \(Int(hrv)) ms, \(abs(Int(d.rounded())))% \(d < 0 ? "below" : "above") your 14-day baseline.")
        }
        if let r = ctx.rhrDelta, abs(r) >= 1 {
            parts.append("Resting HR is \(r > 0 ? "up" : "down") \(abs(Int(r.rounded()))) bpm.")
        }
        parts.append("7-day load is \(ctx.load.status.lowercased()) at \(Int(ctx.load.acute7)).")
        return parts.joined(separator: " ")
    }
}

// MARK: - Conversation preview

private struct ConversationPreview: View {
    let last: CoachMessage?
    @Environment(Router.self) private var router

    var body: some View {
        if let last {
            Button { router.openChat() } label: {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    HStack {
                        MicroLabel("Last from Atlas")
                        Spacer()
                        Text(Fmt.relativeDay(last.date))
                            .textStyle(.footnote)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    HStack(alignment: .top, spacing: Theme.Space.s) {
                        CoachAvatar()
                        Text(last.text.replacingOccurrences(of: "**", with: ""))
                            .textStyle(.callout)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .atlasCard()
            }
            .buttonStyle(.plain)
            .gutter()
        }
    }
}

private struct TalkToAtlasBar: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                AtlasMark(size: 20)
                Text("Talk to Atlas")
                    .textStyle(.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Image(systemName: "arrow.up")
                    .icon(Theme.Icon.small, weight: .bold)
                    .foregroundStyle(Theme.Palette.onPrimary)
                    .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
                    .background(Theme.Palette.textPrimary, in: .circle)
            }
            .padding(.leading, Theme.Space.m)
            .padding(Theme.Space.xxs)
            .modifier(GlassCapsule())
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("talkToAtlas")
    }
}
