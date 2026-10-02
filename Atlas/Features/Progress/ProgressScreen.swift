import SwiftUI
import SwiftData
import Charts

struct ProgressScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Query(sort: \Measurement.date) private var all: [Measurement]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    if let goal = app.context.goal {
                        let points = all.filter { $0.metric == goal.metric }
                        GoalHero(goal: goal)
                        ProjectionChart(goal: goal, points: points)
                        MilestonesCard(goal: goal, points: points)
                        HistoryCard(goal: goal, points: points)
                    } else {
                        EmptyStateView(symbol: "flag.checkered", title: "No goal yet", message: "Set a goal in Settings to see your projection.")
                            .atlasCard()
                    }
                }
                .gutter()
                .padding(.bottom, Theme.Space.xxxl)
            }
            .atlasScreenBackground()
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.sheet = .settings
                    } label: {
                        Image(systemName: "gearshape").icon(Theme.Icon.regular)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if app.context.goal != nil {
                    Button {
                        router.sheet = .measurement
                    } label: {
                        Label("Log measurement", systemImage: "plus")
                    }
                    .buttonStyle(.atlasPrimary)
                    .accessibilityIdentifier("logMeasurement")
                    .gutter()
                    .padding(.top, Theme.Space.s)
                    .padding(.bottom, Theme.Space.xs)
                    .bottomBarScrim()
                }
            }
        }
    }
}

extension ProjectionStatus {
    var color: Color {
        switch self {
        case .ahead, .onTrack, .reached: Theme.Palette.recovery
        case .behind: Theme.Palette.fuel
        case .insufficientData: Theme.Palette.textTertiary
        }
    }
}

// MARK: - Hero

private struct GoalHero: View {
    let goal: GoalSnapshot
    @Environment(AppState.self) private var app

    var body: some View {
        let units = app.context.units
        let p = goal.projection
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                MicroLabel(goal.title, color: Theme.Palette.accent)
                Spacer()
                StatusChip(text: p.status.title, dot: p.status.color)
            }
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Text(Fmt.metric(goal.current, metric: goal.metric, units: units, customUnit: goal.customUnit))
                    .textStyle(.metricXL)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText(value: goal.current))
                Image(systemName: "arrow.right").icon(Theme.Icon.regular).foregroundStyle(Theme.Palette.textTertiary)
                Text(Fmt.metric(goal.target, metric: goal.metric, units: units, customUnit: goal.customUnit))
                    .textStyle(.metricL)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            ProgressTrack(fraction: p.progress, color: Theme.Palette.accentFill, height: 8)
            Text(projectionLine)
                .textStyle(.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .atlasCard(padding: Theme.Space.hero)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goalHero")
    }

    private var projectionLine: String {
        let p = goal.projection
        let due = goal.targetDate.formatted(.dateTime.month(.abbreviated).day())
        switch p.status {
        case .reached: return "Goal reached. Time to set the next one."
        case .insufficientData: return "Log two or more measurements to project your finish. Target: \(due)."
        default:
            guard let d = p.projectedDate else { return "\(goal.daysLeft) days left · target \(due)." }
            let when = d.formatted(.dateTime.month(.abbreviated).day())
            if p.daysVsTarget > 0 { return "At this pace you hit it \(when) — \(p.daysVsTarget) days early." }
            if p.daysVsTarget < 0 { return "At this pace you land \(when), \(-p.daysVsTarget) days after your \(due) target." }
            return "On pace to land right on \(due)."
        }
    }
}

// MARK: - Chart

private struct ProjectionChart: View {
    let goal: GoalSnapshot
    let points: [Measurement]
    @Environment(AppState.self) private var app

    private struct Point: Identifiable { let date: Date; let value: Double; var id: Date { date } }

    var body: some View {
        let units = app.context.units
        let dim = goal.metric.dimension
        let actual = (points.isEmpty ? [Point(date: goal.startDate, value: goal.baseline)] : points.sorted { $0.date < $1.date }.map { Point(date: $0.date, value: $0.value) })
            .map { Point(date: $0.date, value: UnitConvert.display($0.value, dimension: dim, units: units)) }
        let last = actual.last ?? Point(date: app.context.now, value: UnitConvert.display(goal.current, dimension: dim, units: units))
        let end = min(goal.projection.projectedDate ?? goal.targetDate, goal.targetDate.addingTimeInterval(86400 * 60))
        let days = max(0, end.timeIntervalSince(last.date) / 86400)
        let projEnd = last.value + UnitConvert.display(goal.projection.slopePerDay, dimension: dim, units: units) * days
        let target = UnitConvert.display(goal.target, dimension: dim, units: units)
        let values = actual.map(\.value) + [target, projEnd]
        let lo = (values.min() ?? 0), hi = (values.max() ?? 1)
        let pad = max(0.5, (hi - lo) * 0.15)

        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                SectionHeader(title: "Projection")
                Spacer()
                HStack(spacing: Theme.Space.s) {
                    key("Actual", Theme.Palette.accent, dashed: false)
                    key("Projected", Theme.Palette.textSecondary, dashed: true)
                }
            }
            Chart {
                ForEach(actual) { p in
                    AreaMark(x: .value("Date", p.date), yStart: .value("Base", lo - pad), yEnd: .value("Value", p.value), series: .value("Series", "ActualArea"))
                        .foregroundStyle(LinearGradient(colors: [Theme.Palette.accent.opacity(0.22), Theme.Palette.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
                ForEach(actual) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Value", p.value), series: .value("Series", "Actual"))
                        .foregroundStyle(Theme.Palette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                ForEach(actual) { p in
                    PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                        .foregroundStyle(Theme.Palette.accent)
                        .symbolSize(28)
                }
                if goal.projection.status != .insufficientData && days > 0 {
                    LineMark(x: .value("Date", last.date), y: .value("Value", last.value), series: .value("Series", "Projected"))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    LineMark(x: .value("Date", end), y: .value("Value", projEnd), series: .value("Series", "Projected"))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Target \(UnitConvert.number(target)) \(UnitConvert.unit(dim, units: units, custom: goal.customUnit ?? ""))")
                            .textStyle(.micro)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                RuleMark(x: .value("Deadline", goal.targetDate))
                    .foregroundStyle(Theme.Palette.hairline)
            }
            .chartYScale(domain: (lo - pad)...(hi + pad))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Theme.Palette.hairline)
                    AxisValueLabel().foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .frame(height: 220)
            .accessibilityLabel("Projection chart. Current \(UnitConvert.number(last.value)), target \(UnitConvert.number(target)).")
        }
        .atlasCard(padding: Theme.Space.hero)
    }

    private func key(_ label: String, _ color: Color, dashed: Bool) -> some View {
        HStack(spacing: Theme.Space.xxs) {
            Capsule().fill(color).frame(width: dashed ? 8 : 14, height: 2)
            if dashed { Capsule().fill(color).frame(width: 4, height: 2) }
            Text(label).textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
        }
    }
}

// MARK: - Milestones

private struct MilestonesCard: View {
    let goal: GoalSnapshot
    let points: [Measurement]
    @Environment(AppState.self) private var app

    var body: some View {
        let milestones = ProjectionEngine.milestones(goal: goal, measurements: points.map { ($0.date, $0.value) }, now: app.context.now, units: app.context.units)
        if !milestones.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(title: "Milestones")
                VStack(spacing: 0) {
                    ForEach(milestones) { m in
                        HStack(spacing: Theme.Space.s) {
                            Image(systemName: m.isReached ? "checkmark.circle.fill" : "circle")
                                .icon(Theme.Icon.large, weight: .regular)
                                .foregroundStyle(m.isReached ? Theme.Palette.accent : Theme.Palette.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title).textStyle(.headline).foregroundStyle(m.isReached ? Theme.Palette.textSecondary : Theme.Palette.textPrimary)
                                Text(m.date.formatted(.dateTime.month(.abbreviated).day())).textStyle(.footnote).foregroundStyle(Theme.Palette.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, Theme.Space.xs)
                        .accessibilityElement(children: .combine)
                    }
                }
                .atlasCard()
            }
        }
    }
}

// MARK: - History

private struct HistoryCard: View {
    let goal: GoalSnapshot
    let points: [Measurement]
    @Environment(AppState.self) private var app

    var body: some View {
        let list = Array(points.reversed().prefix(8))
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(title: "History")
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, m in
                        HStack {
                            Text(m.date.formatted(.dateTime.month(.abbreviated).day().year()))
                                .textStyle(.callout)
                                .foregroundStyle(Theme.Palette.textSecondary)
                            Spacer()
                            if i + 1 < list.count {
                                let delta = m.value - list[i + 1].value
                                let good = (goal.target >= goal.baseline) == (delta >= 0)
                                Text("\(delta >= 0 ? "+" : "−")\(UnitConvert.number(abs(UnitConvert.display(delta, dimension: goal.metric.dimension, units: app.context.units))))")
                                    .textStyle(.footnote)
                                    .foregroundStyle(delta == 0 ? Theme.Palette.textTertiary : (good ? Theme.Palette.recovery : Theme.Palette.fuel))
                            }
                            Text(Fmt.metric(m.value, metric: goal.metric, units: app.context.units, customUnit: goal.customUnit))
                                .textStyle(.metricS)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .frame(minWidth: 72, alignment: .trailing)
                        }
                        .padding(.vertical, Theme.Space.xs)
                        .contextMenu {
                            Button(role: .destructive) { app.deleteMeasurement(m) } label: { Label("Delete", systemImage: "trash") }
                        }
                        if m.id != list.last?.id { Hairline() }
                    }
                }
                .atlasCard()
            }
        }
    }
}
