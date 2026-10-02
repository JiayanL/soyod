import SwiftUI

/// Itemized food list with portion steppers + delete (used by Snap review and Log meal).
struct FoodItemsEditor: View {
    @Binding var items: [FoodItem]
    var showsConfidence = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach($items) { $item in
                HStack(spacing: Theme.Space.s) {
                    Text(item.emoji ?? "🍽️")
                        .textStyle(.title)
                        .frame(width: 40, height: 40)
                        .background(Theme.Palette.fill, in: .circle)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .textStyle(.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(Int(item.kcal.rounded())) kcal · \(Int(item.protein.rounded()))P \(Int(item.carbs.rounded()))C \(Int(item.fat.rounded()))F")
                            .textStyle(.footnote)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        HStack(spacing: Theme.Space.xxs) {
                            Text(item.servingDescription)
                            if showsConfidence, let c = item.confidence {
                                Text("· \(Int((c * 100).rounded()))%")
                            }
                        }
                        .textStyle(.footnote)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                    }
                    Spacer(minLength: Theme.Space.xs)
                    QuantityStepper(value: $item.quantity, step: 0.5, range: 0.5...6)
                        .fixedSize()
                }
                .padding(.vertical, Theme.Space.s)
                .contextMenu {
                    Button(role: .destructive) {
                        remove(item.id)
                    } label: { Label("Remove", systemImage: "trash") }
                }
                .accessibilityAction(named: "Remove") { remove(item.id) }
                if item.id != items.last?.id { Hairline(leading: 52) }
            }
        }
    }

    private func remove(_ id: UUID) {
        withAnimation(Theme.Motion.standard) { items.removeAll { $0.id == id } }
    }
}

/// Totals row: kcal + P/C/F.
struct MacroTotalsRow: View {
    let items: [FoodItem]

    var body: some View {
        let kcal = items.reduce(0) { $0 + $1.kcal }
        let p = items.reduce(0) { $0 + $1.protein }
        let c = items.reduce(0) { $0 + $1.carbs }
        let f = items.reduce(0) { $0 + $1.fat }
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                MicroLabel("Total")
                MetricText(value: Fmt.kcal(kcal), unit: "kcal", style: .metricL)
            }
            Spacer()
            macro("P", p, Theme.Palette.fuel)
            macro("C", c, Theme.Palette.sleep)
            macro("F", f, Theme.Palette.recovery)
        }
    }

    private func macro(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label).textStyle(.micro).foregroundStyle(color)
            Text("\(Int(value.rounded()))g").textStyle(.metricS).foregroundStyle(Theme.Palette.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Meal type pills.
struct MealTypePicker: View {
    @Binding var selection: MealType

    var body: some View {
        SegmentedPills(options: MealType.allCases.map { ($0, $0.title) }, selection: $selection)
    }
}
