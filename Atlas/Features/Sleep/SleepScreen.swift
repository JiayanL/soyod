import SwiftUI
import SwiftData
import Charts

struct SleepScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Query(sort: \SleepSession.end, order: .reverse) private var sessions: [SleepSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    if let last = app.context.lastSleep {
                        SleepHero(summary: last)
                        if let session = sessions.first, !session.stages.isEmpty {
                            StagesCard(session: session, summary: last)
                        }
                        VitalsGrid(summary: last)
                        BedtimeCard()
                        NightsChart(nights: app.context.recentSleep)
                    } else {
                        EmptyStateView(symbol: "moon.zzz.fill", title: "No sleep yet", message: "Connect Apple Health or log last night manually to unlock sleep and recovery scores.", ctaTitle: "Log sleep") {
                            router.sheet = .manualSleep
                        }
                        .atlasCard()
                    }
                }
                .gutter()
                .padding(.bottom, Theme.Space.xxxl)
            }
            .background(alignment: .top) {
                AtmosphereBackground(tint: Theme.Palette.sleep).ignoresSafeArea()
            }
            .atlasScreenBackground()
            .navigationTitle("Sleep")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.sheet = .manualSleep
                    } label: {
                        Image(systemName: "plus").icon(Theme.Icon.regular)
                    }
                    .accessibilityLabel("Log sleep manually")
                    .accessibilityIdentifier("logSleep")
                }
            }
        }
    }
}

// MARK: - Hero

private struct SleepHero: View {
    let summary: SleepSummary
    @Environment(AppState.self) private var app

    var body: some View {
        let recovery = app.context.recoveryScore
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                MicroLabel("Last night · \(Fmt.clock(summary.start)) – \(Fmt.clock(summary.end))", color: Theme.Palette.sleep)
                Text(verdict)
                    .textStyle(.displayS)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Theme.Space.l) {
                ScoreRing(progress: Double(summary.score) / 100, color: Theme.Palette.sleep, diameter: 128) {
                    VStack(spacing: 0) {
                        Text("\(summary.score)").textStyle(.metricL).foregroundStyle(Theme.Palette.textPrimary)
                        Text("Sleep").textStyle(.micro).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .accessibilityLabel("Sleep score \(summary.score)")
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    stat("Asleep", Fmt.duration(minutes: summary.asleepMin), sub: "of \(Fmt.duration(minutes: app.context.sleepNeedMin)) need")
                    if let recovery {
                        stat("Recovery", "\(recovery)%", sub: Theme.Palette.scoreWord(recovery), color: Theme.Palette.score(recovery))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .atlasCard(padding: Theme.Space.hero)
    }

    private var verdict: String {
        let debt = app.context.sleepNeedMin - summary.asleepMin
        if debt > 60 { return "Short night. You're \(Fmt.duration(minutes: debt)) under your need." }
        if summary.score >= 85 { return "Excellent night. You're recharged." }
        return "Decent night. Room to bank a little more."
    }

    private func stat(_ label: String, _ value: String, sub: String, color: Color = Theme.Palette.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MicroLabel(label)
            Text(value).textStyle(.metricM).foregroundStyle(color)
            Text(sub).textStyle(.footnote).foregroundStyle(Theme.Palette.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stages

private struct StagesCard: View {
    let session: SleepSession
    let summary: SleepSummary

    var body: some View {
        let segments = session.stages.enumerated().map { i, s in
            Hypnogram.Segment(id: i, level: s.stage.level, start: s.start, end: s.end)
        }
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionHeader(title: "Stages")
            Hypnogram(segments: segments)
            HStack(spacing: 0) {
                legend("Awake", summary.awakeMin, Theme.Palette.stageAwake)
                legend("REM", summary.remMin, Theme.Palette.stageREM)
                legend("Core", summary.coreMin, Theme.Palette.stageCore)
                legend("Deep", summary.deepMin, Theme.Palette.stageDeep)
            }
        }
        .atlasCard(padding: Theme.Space.hero)
    }

    private func legend(_ name: String, _ minutes: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Theme.Space.xxs) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(name).textStyle(.micro).foregroundStyle(Theme.Palette.textSecondary)
            }
            Text(Fmt.duration(minutes: minutes)).textStyle(.metricS).foregroundStyle(Theme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension SleepStage {
    var level: Int {
        switch self {
        case .awake: 0
        case .rem: 1
        case .core: 2
        case .deep: 3
        }
    }
}

// MARK: - Vitals

private struct VitalsGrid: View {
    let summary: SleepSummary
    @Environment(AppState.self) private var app

    var body: some View {
        let ctx = app.context
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.s), GridItem(.flexible(), spacing: Theme.Space.s)], spacing: Theme.Space.s) {
            MetricTile(symbol: "waveform.path.ecg", label: "HRV", value: summary.hrvMs.map { "\(Int($0))" } ?? "–", unit: "ms",
                       delta: ctx.hrvDeltaPct.map { "\(abs(Int($0.rounded())))% vs avg" }, deltaPositive: ctx.hrvDeltaPct.map { $0 >= 0 },
                       color: Theme.Palette.recovery)
            MetricTile(symbol: "heart.fill", label: "Resting HR", value: summary.restingHR.map { "\(Int($0))" } ?? "–", unit: "bpm",
                       delta: ctx.rhrDelta.map { "\(abs(Int($0.rounded()))) bpm vs avg" }, deltaPositive: ctx.rhrDelta.map { $0 <= 0 },
                       color: Theme.Palette.train)
            MetricTile(symbol: "bed.double.fill", label: "Efficiency", value: "\(Int((summary.efficiency * 100).rounded()))", unit: "%", color: Theme.Palette.sleep)
            MetricTile(symbol: "moon.stars.fill", label: "Deep + REM", value: Fmt.duration(minutes: summary.deepMin + summary.remMin), color: Theme.Palette.stageDeep)
        }
    }
}

// MARK: - Bedtime

private struct BedtimeCard: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let ctx = app.context
        HStack(spacing: Theme.Space.m) {
            IconDisk(symbol: "moon.fill", color: Theme.Palette.sleep)
            VStack(alignment: .leading, spacing: 2) {
                MicroLabel("Tonight")
                Text("In bed by \(Fmt.clock(ctx.recommendedBedtime))")
                    .textStyle(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Covers your \(Fmt.duration(minutes: ctx.sleepNeedMin)) need before a 7:00 wake.")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .atlasCard()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 7 nights

private struct NightsChart: View {
    let nights: [SleepSummary]
    @Environment(AppState.self) private var app

    var body: some View {
        if nights.count > 1 {
            let avg = nights.reduce(0) { $0 + $1.asleepMin } / nights.count
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        MicroLabel("\(nights.count)-night average")
                        Text(Fmt.duration(minutes: avg)).textStyle(.metricM).foregroundStyle(Theme.Palette.textPrimary)
                    }
                    Spacer()
                }
                Chart {
                    ForEach(nights, id: \.end) { n in
                        BarMark(x: .value("Night", n.end, unit: .day), y: .value("Hours", Double(n.asleepMin) / 60), width: .ratio(0.55))
                            .foregroundStyle(n.asleepMin < app.context.sleepNeedMin - 60 ? Theme.Palette.sleep.opacity(0.45) : Theme.Palette.sleep)
                            .clipShape(.rect(cornerRadius: Theme.Radius.tiny / 2))
                    }
                    RuleMark(y: .value("Need", Double(app.context.sleepNeedMin) / 60))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow)).foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, 4, 8]) { v in
                        AxisGridLine().foregroundStyle(Theme.Palette.hairline)
                        AxisValueLabel { Text("\(v.as(Int.self) ?? 0)h") }.foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                .frame(height: 150)
                .accessibilityLabel("Sleep hours over the last \(nights.count) nights")
            }
            .atlasCard(padding: Theme.Space.hero)
        }
    }
}
