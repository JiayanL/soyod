import SwiftUI

/// Final onboarding screen: staggered plan reveal (kcal → macros → split → sleep → milestones).
struct PlanRevealStep: View {
    let draft: OnboardingDraft
    let onStart: () -> Void

    @State private var preview: PlanPreview?
    @State private var revealed = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    MicroLabel("Your plan is ready", color: Theme.Palette.accent)
                    Text(draft.name.isEmpty ? "Here's how we get there." : "Here's how we get there, \(draft.name).")
                        .textStyle(.displayS)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let preview {
                    calories(preview).reveal(revealed >= 1)
                    split(preview).reveal(revealed >= 2)
                    sleep(preview).reveal(revealed >= 3)
                    milestones(preview).reveal(revealed >= 4)
                    Text(preview.rationale)
                        .textStyle(.callout)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .reveal(revealed >= 4)
                }
            }
            .gutter()
            .padding(.vertical, Theme.Space.xl)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Start with Atlas", action: onStart)
                .buttonStyle(.atlasHero)
                .accessibilityIdentifier("onbFinish")
                .gutter()
                .padding(.top, Theme.Space.s)
                .padding(.bottom, Theme.Space.xs)
                .background(Theme.Palette.bg.opacity(0.94))
                .opacity(revealed >= 4 ? 1 : 0.0)
        }
        .task {
            preview = draft.preview()
            if reduceMotion {
                revealed = 4
                return
            }
            for i in 1...4 {
                try? await Task.sleep(for: .milliseconds(i == 1 ? 250 : 380))
                withAnimation(Theme.Motion.standard) { revealed = i }
            }
        }
        .sensoryFeedback(.success, trigger: revealed == 4)
    }

    private func calories(_ p: PlanPreview) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            MicroLabel("Daily target")
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xxs) {
                Text(revealed >= 1 ? p.targets.kcal : 0, format: .number)
                    .textStyle(.metricXL)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText(value: Double(p.targets.kcal)))
                Text("kcal").textStyle(.headline).foregroundStyle(Theme.Palette.textSecondary)
            }
            HStack(spacing: Theme.Space.m) {
                MacroBar(label: "Protein", value: Double(p.targets.proteinG), target: Double(p.targets.proteinG), color: Theme.Palette.fuel)
                MacroBar(label: "Carbs", value: Double(p.targets.carbsG), target: Double(p.targets.carbsG), color: Theme.Palette.sleep)
                MacroBar(label: "Fat", value: Double(p.targets.fatG), target: Double(p.targets.fatG), color: Theme.Palette.recovery)
            }
        }
        .atlasCard(padding: Theme.Space.hero)
    }

    private func split(_ p: PlanPreview) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                MicroLabel("Your week")
                Spacer()
                Text("\(p.split.count) sessions").textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
            }
            HStack(spacing: Theme.Space.xxs) {
                ForEach(1...7, id: \.self) { day in
                    let session = p.split.first { $0.weekday == day }
                    VStack(spacing: Theme.Space.xxs) {
                        Text(weekdays[day - 1]).textStyle(.micro).foregroundStyle(Theme.Palette.textTertiary)
                        Circle()
                            .fill(session == nil ? Theme.Palette.fill : Theme.Palette.train)
                            .frame(width: 10, height: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 0) {
                ForEach(p.split) { s in
                    HStack(spacing: Theme.Space.s) {
                        Text(Self.weekdayName(s.weekday))
                            .textStyle(.micro)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .frame(width: 36, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                            Text(s.focus).textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer()
                        Text("\(s.durationMin) min").textStyle(.metricS).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(.vertical, Theme.Space.xs)
                    if s.id != p.split.last?.id { Hairline(leading: 48) }
                }
            }
        }
        .atlasCard(padding: Theme.Space.hero)
    }

    private func sleep(_ p: PlanPreview) -> some View {
        HStack(spacing: Theme.Space.m) {
            IconDisk(symbol: "moon.stars.fill", color: Theme.Palette.sleep, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                MicroLabel("Sleep target")
                MetricText.duration(minutes: p.sleepTargetMin, style: .metricM)
            }
            Spacer()
            Text("Adjusts nightly to your training load")
                .textStyle(.footnote)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140, alignment: .trailing)
        }
        .atlasCard(padding: Theme.Space.hero)
    }

    private func milestones(_ p: PlanPreview) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            MicroLabel("Milestones")
            ForEach(Array(p.milestones.enumerated()), id: \.element.id) { i, m in
                HStack(alignment: .top, spacing: Theme.Space.s) {
                    VStack(spacing: 0) {
                        Circle()
                            .strokeBorder(i == p.milestones.count - 1 ? Theme.Palette.accent : Theme.Palette.textTertiary, lineWidth: 2)
                            .frame(width: 12, height: 12)
                        if i < p.milestones.count - 1 {
                            Rectangle().fill(Theme.Palette.hairline).frame(width: 1).frame(maxHeight: .infinity)
                        }
                    }
                    .padding(.top, Theme.Space.xxs)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.title).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                        Text(m.date, format: .dateTime.month(.abbreviated).day())
                            .textStyle(.footnote)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(.bottom, Theme.Space.xs)
                    Spacer()
                }
            }
        }
        .atlasCard(padding: Theme.Space.hero)
    }

    static func weekdayName(_ weekday: Int) -> String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][max(0, min(6, weekday - 1))]
    }
}

extension View {
    /// Fade + rise reveal used by the plan reveal.
    func reveal(_ shown: Bool) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : Theme.Space.m)
    }
}
