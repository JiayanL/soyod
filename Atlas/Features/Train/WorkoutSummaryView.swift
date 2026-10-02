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
                        .padding(.top, Theme.Space.l)
                    Text(result.prs.isEmpty ? "Session logged." : (result.prs.count == 1 ? "New personal record." : "\(result.prs.count) new personal records."))
                        .textStyle(.display)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(w.title)
                        .textStyle(.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(coachNote)
                        .textStyle(.callout)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Space.xs)
                }
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(stats(w, units: units).enumerated()), id: \.offset) { i, stat in
                        if i > 0 { Rectangle().fill(Theme.Palette.hairline).frame(width: 1).padding(.vertical, Theme.Space.xxs) }
                        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                            MicroLabel(stat.label)
                            Text(stat.value)
                                .textStyle(.metricS)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, i > 0 ? Theme.Space.s : 0)
                        .accessibilityElement(children: .combine)
                    }
                }
                .atlasCard()
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
                .padding(.top, Theme.Space.s)
                .padding(.bottom, Theme.Space.xs)
                .bottomBarScrim()
        }
        .sensoryFeedback(result.prs.isEmpty ? .success : .increase, trigger: celebrate)
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            celebrate += 1
        }
    }

    private func stats(_ w: Workout, units: UnitSystem) -> [(label: String, value: String)] {
        var out: [(label: String, value: String)] = [("Time", Fmt.duration(seconds: w.durationSec)), ("Load", "\(Int(w.load))")]
        if w.kind == .strength {
            out.append(("Volume", Fmt.weight(kg: w.volumeKg, units: units)))
            out.append(("Sets", "\(w.exercises.flatMap(\.sets).count)"))
        } else {
            if let d = w.distanceM, d > 0 { out.append(("Distance", Fmt.distance(m: d, units: units))) }
            if let p = w.paceSecPerKm { out.append(("Pace", Fmt.pace(secPerKm: p, units: units))) }
        }
        return out
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
