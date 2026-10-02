import SwiftUI

/// Describe (text parse) / Search / Quick add meal logging.
struct LogMealSheet: View {
    enum Mode: String, CaseIterable { case describe, search, quick
        var title: String { self == .describe ? "Describe" : self == .search ? "Search" : "Quick add" }
    }

    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .describe
    @State private var mealType: MealType
    @State private var text = ""
    @State private var query = ""
    @State private var items: [FoodItem] = []
    @State private var title = ""
    @State private var quick = QuickMacros()
    @State private var saved = false
    @FocusState private var focused: Bool

    struct QuickMacros { var kcal: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0 }

    init(initialType: MealType?) {
        _mealType = State(initialValue: initialType ?? AppState.defaultMealType(at: AppClock.now))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    SegmentedPills(options: Mode.allCases.map { ($0, $0.title) }, selection: $mode)
                    switch mode {
                    case .describe: describe
                    case .search: search
                    case .quick: quickAdd
                    }
                    if mode != .quick && !items.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Space.s) {
                            MicroLabel("On the plate")
                            FoodItemsEditor(items: $items)
                                .atlasCard()
                        }
                        .transition(.opacity)
                    }
                    FormGroup(title: "Meal") { MealTypePicker(selection: $mealType) }
                }
                .gutter()
                .padding(.top, Theme.Space.m)
                .padding(.bottom, Theme.Space.xxxl)
                .animation(Theme.Motion.standard, value: items)
            }
            .scrollDismissesKeyboard(.interactively)
            .atlasScreenBackground()
            .navigationTitle("Log a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Theme.Space.s) {
                    if !finalItems.isEmpty { MacroTotalsRow(items: finalItems) }
                    Button("Log meal", action: save)
                        .buttonStyle(.atlasPrimary)
                        .disabled(finalItems.isEmpty)
                        .accessibilityIdentifier("logMealButton")
                }
                .gutter()
                .padding(.vertical, Theme.Space.s)
                .background(.regularMaterial)
            }
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    private var describe: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            TextField("e.g. 2 eggs, toast with avocado, black coffee", text: $text, axis: .vertical)
                .textStyle(.body)
                .lineLimit(3...6)
                .focused($focused)
                .padding(Theme.Space.m)
                .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                .accessibilityIdentifier("describeField")
                .onSubmit(parse)
            HStack {
                Text("Atlas estimates portions from the food database. Adjust below.")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textTertiary)
                Spacer()
                Button("Estimate", action: parse)
                    .buttonStyle(.atlasPrimaryCompact)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("estimateButton")
            }
        }
    }

    private var search: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.Palette.textTertiary)
                TextField("Search 260+ foods", text: $query)
                    .textStyle(.body)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("foodSearch")
            }
            .padding(Theme.Space.s)
            .background(Theme.Palette.fill, in: .capsule)
            let results = query.isEmpty ? FoodDatabase.shared.quickPicks : FoodDatabase.shared.search(query, limit: 25)
            VStack(spacing: 0) {
                ForEach(results) { entry in
                    Button {
                        withAnimation(Theme.Motion.standard) { items.append(entry.item()) }
                    } label: {
                        HStack(spacing: Theme.Space.s) {
                            Text(entry.emoji).textStyle(.title).frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
                                Text("\(entry.serving) · \(Int(entry.kcal)) kcal · P \(Int(entry.protein))")
                                    .textStyle(.footnote)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .icon(Theme.Icon.large, weight: .regular)
                                .foregroundStyle(Theme.Palette.textPrimary)
                        }
                        .padding(.vertical, Theme.Space.xs)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(entry.name)")
                    if entry.id != results.last?.id { Hairline(leading: 48) }
                }
                if results.isEmpty {
                    EmptyStateView(symbol: "magnifyingglass", title: "No match", message: "Try a simpler name, or describe it instead.")
                }
            }
            .atlasCard()
        }
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            TextField("Name (optional)", text: $title)
                .textStyle(.headline)
                .padding(Theme.Space.m)
                .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
            NumberField(label: "Calories", value: $quick.kcal, unit: "kcal", decimals: 0, identifier: "quickKcal")
            HStack(spacing: Theme.Space.s) {
                NumberField(label: "Protein", value: $quick.protein, unit: "g", decimals: 0)
                NumberField(label: "Carbs", value: $quick.carbs, unit: "g", decimals: 0)
                NumberField(label: "Fat", value: $quick.fat, unit: "g", decimals: 0)
            }
        }
    }

    private var finalItems: [FoodItem] {
        if mode == .quick {
            guard quick.kcal > 0 else { return [] }
            return [FoodItem(name: title.isEmpty ? "Quick add" : title, servingDescription: "1 entry", kcalPerServing: quick.kcal, proteinPerServing: quick.protein, carbsPerServing: quick.carbs, fatPerServing: quick.fat, emoji: "⚡️")]
        }
        return items
    }

    private func parse() {
        let parsed = FoodTextParser.parse(text)
        withAnimation(Theme.Motion.standard) { items.append(contentsOf: parsed) }
        if !parsed.isEmpty { text = "" }
        focused = false
    }

    private func save() {
        let list = finalItems
        guard !list.isEmpty else { return }
        let name = mode == .quick ? list[0].name : MealNaming.title(for: list)
        let source: MealSource = mode == .describe ? .text : mode == .search ? .search : .quick
        app.logMeal(title: name, mealType: mealType, items: list, photo: nil, source: source, date: AppClock.now)
        saved = true
        dismiss()
    }
}

enum MealNaming {
    static func title(for items: [FoodItem]) -> String {
        let names = items.prefix(2).map(\.name)
        guard let first = names.first else { return "Meal" }
        let base = names.count > 1 ? "\(first) & \(names[1].lowercased())" : first
        return items.count > 2 ? base + " +\(items.count - 2)" : base
    }
}
