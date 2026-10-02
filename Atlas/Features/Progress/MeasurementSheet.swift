import SwiftUI

struct MeasurementSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double = 0
    @State private var date = AppClock.now
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            if let goal = app.context.goal {
                let units = app.context.units
                let dim = goal.metric.dimension
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                            MicroLabel(goal.title, color: Theme.Palette.accent)
                            Text("Last: \(Fmt.metric(goal.current, metric: goal.metric, units: units, customUnit: goal.customUnit))")
                                .textStyle(.body)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        NumberField(label: goal.metric == .custom ? goal.title : goal.metric.title, value: $value,
                                    unit: UnitConvert.unit(dim, units: units, custom: goal.customUnit ?? ""),
                                    decimals: dim == .time ? 0 : 1, identifier: "measurementValue")
                        DatePicker("Date", selection: $date, in: ...AppClock.now, displayedComponents: .date)
                            .textStyle(.body)
                            .padding(.horizontal, Theme.Space.m)
                            .padding(.vertical, Theme.Space.xs)
                            .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                        Text(hint(goal.metric))
                            .textStyle(.footnote)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .gutter()
                    .padding(.top, Theme.Space.m)
                }
                .atlasScreenBackground()
                .navigationTitle("Log measurement")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    Button("Save") {
                        app.addMeasurement(value: UnitConvert.canonical(value, dimension: dim, units: units), date: date)
                        dismiss()
                    }
                    .buttonStyle(.atlasPrimary)
                    .disabled(value <= 0)
                    .accessibilityIdentifier("saveMeasurement")
                    .gutter()
                    .padding(.bottom, Theme.Space.xs)
                }
                .onAppear {
                    guard !loaded else { return }
                    value = (UnitConvert.display(goal.current, dimension: dim, units: units) * 10).rounded() / 10
                    loaded = true
                }
            }
        }
    }

    private func hint(_ m: GoalMetric) -> String {
        switch m {
        case .verticalJump: "Best of 3 attempts, fully warmed up. Same wall, same reach."
        case .waist: "Measure at the navel, relaxed, first thing in the morning."
        case .bodyWeight: "Same scale, morning, after the bathroom."
        case .fiveK, .tenK: "Enter your time in seconds from a recent all-out effort."
        default: "Measure under the same conditions each time for a clean trend."
        }
    }
}
