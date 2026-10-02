import SwiftUI

/// Log a run / ride / swim / row / walk or a sport session with pace + load.
struct CardioLogSheet: View {
    enum Mode: String, CaseIterable { case cardio, sport }

    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .cardio
    @State private var type: CardioType = .run
    @State private var sport = "Basketball"
    @State private var minutes: Double = 30
    @State private var distance: Double = 3.1
    @State private var avgHR: Double = 0
    @State private var rpe: Double = 5
    @State private var when = AppClock.now

    private let sports = ["Basketball", "Soccer", "Tennis", "Pickleball", "Climbing", "Volleyball"]
    private var units: UnitSystem { app.context.units }

    private var distanceM: Double { UnitConvert.distanceCanonical(distance, units: units) }
    private var load: Double { ScoreEngine.sessionLoad(durationMin: Int(minutes), rpe: rpe) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    SegmentedPills(options: [(Mode.cardio, "Cardio"), (Mode.sport, "Sport")], selection: $mode)
                    if mode == .cardio {
                        FormGroup(title: "Type") {
                            HStack(spacing: Theme.Space.xs) {
                                ForEach(CardioType.allCases) { t in
                                    Button {
                                        type = t
                                    } label: {
                                        VStack(spacing: Theme.Space.xxs) {
                                            Image(systemName: t.symbol).icon(Theme.Icon.large, weight: .regular)
                                            Text(t.title).textStyle(.footnote)
                                        }
                                        .foregroundStyle(type == t ? Theme.Palette.onPrimary : Theme.Palette.textPrimary)
                                        .frame(maxWidth: .infinity, minHeight: 64)
                                        .background(type == t ? Theme.Palette.textPrimary : Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.small, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(type == t ? .isSelected : [])
                                }
                            }
                        }
                        HStack(spacing: Theme.Space.s) {
                            NumberField(label: "Duration", value: $minutes, unit: "min", decimals: 0, identifier: "cardioMinutes")
                            NumberField(label: "Distance", value: $distance, unit: UnitConvert.distanceUnit(units), decimals: 2, identifier: "cardioDistance")
                        }
                    } else {
                        FormGroup(title: "Sport") {
                            ChipPicker(options: sports.map { ($0, $0) }, isSelected: { $0 == sport }) { sport = $0 }
                        }
                        NumberField(label: "Duration", value: $minutes, unit: "min", decimals: 0)
                    }
                    NumberField(label: "Avg heart rate (optional)", value: $avgHR, unit: "bpm", decimals: 0)
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        HStack {
                            MicroLabel("Effort (RPE)")
                            Spacer()
                            Text("\(Int(rpe)) · \(rpeWord)").textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                        }
                        Slider(value: $rpe, in: 1...10, step: 1)
                            .tint(Theme.Palette.train)
                            .accessibilityValue("\(Int(rpe)) out of 10")
                    }
                    DatePicker("When", selection: $when, in: ...AppClock.now)
                        .textStyle(.body)
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.vertical, Theme.Space.xs)
                        .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                    calcs
                }
                .gutter()
                .padding(.top, Theme.Space.m)
                .padding(.bottom, Theme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .atlasScreenBackground()
            .navigationTitle(mode == .cardio ? "Log \(type.title.lowercased())" : "Log \(sport.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button("Save", action: save)
                    .buttonStyle(.atlasPrimary)
                    .disabled(minutes <= 0)
                    .accessibilityIdentifier("saveCardio")
                    .gutter()
                    .padding(.bottom, Theme.Space.xs)
            }
        }
    }

    private var rpeWord: String {
        switch Int(rpe) {
        case ...3: "Easy"
        case 4...5: "Steady"
        case 6...7: "Hard"
        case 8...9: "Very hard"
        default: "Max"
        }
    }

    private var calcs: some View {
        HStack(spacing: 0) {
            if mode == .cardio && distance > 0 && minutes > 0 {
                calc("Pace", Fmt.pace(secPerKm: minutes * 60 / (distanceM / 1000), units: units))
            }
            calc("Load", "\(Int(load))")
            calc("Est. burn", "\(Int(estimatedKcal)) kcal")
        }
        .atlasCard()
        .accessibilityElement(children: .combine)
    }

    private var estimatedKcal: Double {
        let met = mode == .cardio ? type.met : 7.0
        let kg = app.profile?.weightKg ?? 80
        return met * kg * minutes / 60 * (0.7 + rpe * 0.06)
    }

    private func calc(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            MicroLabel(label)
            Text(value).textStyle(.metricS).foregroundStyle(Theme.Palette.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        let draft: WorkoutDraft
        if mode == .cardio {
            let title = distance > 0 ? "\(UnitConvert.number(distance, decimals: 1)) \(UnitConvert.distanceUnit(units)) \(type.title.lowercased())" : type.title
            draft = WorkoutDraft(kind: .cardio, title: title, start: when, durationSec: Int(minutes * 60), cardioType: type,
                                 distanceM: distance > 0 ? distanceM : nil, avgHR: avgHR > 0 ? Int(avgHR) : nil, rpe: rpe)
        } else {
            draft = WorkoutDraft(kind: .sport, title: sport, start: when, durationSec: Int(minutes * 60),
                                 avgHR: avgHR > 0 ? Int(avgHR) : nil, rpe: rpe, sport: sport)
        }
        let result = app.saveWorkout(draft)
        router.sheet = .workoutSummary(result)
    }
}
