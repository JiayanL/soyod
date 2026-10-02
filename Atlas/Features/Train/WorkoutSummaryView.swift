import SwiftUI
import Pow

/// Post-workout summary: volume, load, PRs (with celebration).
struct WorkoutSummaryView: View {
    let result: WorkoutSaveResult
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrate = 0

    var body: some View {
        let w = result.workout
        let units = app.context.units
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Image(systemName: result.prs.isEmpty ? "checkmark.seal.fill" : "trophy.fill")
                        .icon(Theme.Icon.art, weight: .regular)
                        .foregroundStyle(Theme.Palette.accent)
                        .changeEffect(.spray(origin: .center) {
                            Image(systemName: "star.fill").foregroundStyle(Theme.Palette.accentFill)
                        }, value: celebrate, isEnabled: !reduceMotion)
                        .padding(.top, Theme.Space.xxl)
                    Text(result.prs.isEmpty ? "Session logged." : (result.prs.count == 1 ? "New personal record." : "\(result.prs.count) new personal records."))
                        .textStyle(.display)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(w.title)
                        .textStyle(.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.s), GridItem(.flexible(), spacing: Theme.Space.s)], spacing: Theme.Space.s) {
                    MetricTile(symbol: "clock", label: "Duration", value: Fmt.duration(seconds: w.durationSec), color: Theme.Palette.textSecondary)
                    MetricTile(symbol: "flame.fill", label: "Load", value: "\(Int(w.load))", color: Theme.Palette.train)
                    if w.kind == .strength {
                        MetricTile(symbol: "scalemass", label: "Volume", value: Fmt.weight(kg: w.volumeKg, units: units), color: Theme.Palette.accent)
                        MetricTile(symbol: "number", label: "Sets", value: "\(w.exercises.flatMap(\.sets).count)", color: Theme.Palette.sleep)
                    } else {
                        if let d = w.distanceM, d > 0 {
                            MetricTile(symbol: "point.topleft.down.to.point.bottomright.curvepath", label: "Distance", value: Fmt.distance(m: d, units: units), color: Theme.Palette.recovery)
                        }
                        if let p = w.paceSecPerKm {
                            MetricTile(symbol: "speedometer", label: "Pace", value: Fmt.pace(secPerKm: p, units: units), color: Theme.Palette.sleep)
                        }
                    }
                }
                if !result.prs.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        MicroLabel("Personal records", color: Theme.Palette.accent)
                            .padding(.bottom, Theme.Space.xs)
                        ForEach(result.prs, id: \.self) { pr in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pr.exerciseName).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                                    Text("\(Fmt.weight(kg: pr.weightKg, units: units)) × \(pr.reps)").textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(Fmt.weight(kg: pr.e1RM, units: units)).textStyle(.metricS).foregroundStyle(Theme.Palette.textPrimary)
                                    Text("est. 1RM").textStyle(.micro).foregroundStyle(Theme.Palette.textTertiary)
                                }
                            }
                            .padding(.vertical, Theme.Space.xs)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .atlasCard()
                }
                Text(coachNote)
                    .textStyle(.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .gutter()
            .padding(.bottom, Theme.Space.xxxl)
        }
        .atlasScreenBackground()
        .safeAreaInset(edge: .bottom) {
            Button("Done") { dismiss() }
                .buttonStyle(.atlasPrimary)
                .accessibilityIdentifier("summaryDone")
                .gutter()
                .padding(.bottom, Theme.Space.xs)
        }
        .sensoryFeedback(result.prs.isEmpty ? .success : .increase, trigger: celebrate)
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            celebrate += 1
        }
    }

    private var coachNote: String {
        let ctx = app.context
        let remaining = max(0, Double(ctx.targets.proteinG) - ctx.eaten.protein)
        if remaining > 20 {
            return "Get \(Int(min(45, remaining))) g of protein in within the next 2 hours — you have \(Int(remaining)) g left today."
        }
        return "Protein is covered today. Prioritize sleep — aim for bed by \(Fmt.clock(ctx.recommendedBedtime))."
    }
}
