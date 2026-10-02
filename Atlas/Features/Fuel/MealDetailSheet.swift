import SwiftUI
import SwiftData

/// Edit or delete a logged meal.
struct MealDetailSheet: View {
    let mealID: UUID
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [MealEntry]
    @State private var items: [FoodItem] = []
    @State private var mealType: MealType = .lunch
    @State private var loaded = false

    init(mealID: UUID) {
        self.mealID = mealID
        _matches = Query(filter: #Predicate<MealEntry> { $0.id == mealID })
    }

    var body: some View {
        NavigationStack {
            if let meal = matches.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        HStack(spacing: Theme.Space.m) {
                            MealThumbnail(meal: meal, size: 72)
                            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                                Text(meal.title)
                                    .textStyle(.serifTitle)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(Fmt.relativeDay(meal.date)) · \(Fmt.clock(meal.date))")
                                    .textStyle(.footnote)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        MacroTotalsRow(items: items).atlasCard()
                        FoodItemsEditor(items: $items).atlasCard()
                        FormGroup(title: "Meal") { MealTypePicker(selection: $mealType) }
                        Button(role: .destructive) {
                            app.deleteMeal(meal)
                            dismiss()
                        } label: {
                            Text("Delete meal")
                                .textStyle(.headline)
                                .foregroundStyle(Theme.Palette.scoreLow)
                                .frame(maxWidth: .infinity, minHeight: Theme.Size.minTap)
                        }
                        .buttonStyle(.plain)
                    }
                    .gutter()
                    .padding(.vertical, Theme.Space.l)
                }
                .atlasScreenBackground()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            meal.items = items
                            meal.mealType = mealType
                            app.updateMeal(meal)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(items.isEmpty)
                    }
                }
                .onAppear {
                    guard !loaded else { return }
                    items = meal.items
                    mealType = meal.mealType
                    loaded = true
                }
            } else {
                EmptyStateView(symbol: "fork.knife", title: "Meal not found", message: "It may have been deleted.")
            }
        }
    }
}
