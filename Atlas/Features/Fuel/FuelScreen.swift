import SwiftUI
import SwiftData
import Charts

struct FuelScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]

    private var todayMeals: [MealEntry] {
        let cal = Calendar.current
        return meals.filter { cal.isDate($0.date, inSameDayAs: app.context.now) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    CaloriesHero()
                    MacroTrio()
                    if app.context.eatingWindow != nil { EatingWindowCard() }
                    todaySection
                    WeekChart(meals: meals, now: app.context.now, target: app.context.targets.kcal)
                }
                .gutter()
                .padding(.bottom, Theme.Space.xxxl)
            }
            .atlasScreenBackground()
            .navigationTitle("Fuel")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        router.sheet = .snap
                    } label: {
                        Image(systemName: "camera.fill").icon(Theme.Icon.regular)
                    }
                    .accessibilityLabel("Snap a meal")
                    .accessibilityIdentifier("snapButton")
                    QuickLogToolbarButton()
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: Theme.Space.s) {
                    Button {
                        router.sheet = .snap
                    } label: {
                        Label("Snap meal", systemImage: "camera.fill")
                    }
                    .buttonStyle(.atlasPrimary)
                    Button {
                        router.sheet = .logMeal(nil)
                    } label: {
                        Label("Describe", systemImage: "text.bubble")
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                    .background(Theme.Palette.bg, in: .capsule)
                    .accessibilityIdentifier("describeMeal")
                }
                .gutter()
                .padding(.top, Theme.Space.s)
                .padding(.bottom, Theme.Space.xs)
                .bottomBarScrim()
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader(title: "Today")
            if todayMeals.isEmpty {
                EmptyStateView(symbol: "fork.knife", title: "No meals yet", message: "Snap a photo or describe what you ate — Atlas does the math.", ctaTitle: "Snap a meal") {
                    router.sheet = .snap
                }
                .atlasCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(todayMeals) { meal in
                        Button {
                            router.sheet = .mealDetail(meal.id)
                        } label: {
                            MealRow(meal: meal)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { app.deleteMeal(meal) } label: { Label("Delete", systemImage: "trash") }
                        }
                        if meal.id != todayMeals.last?.id { Hairline(leading: Theme.Size.thumbnail + Theme.Space.s) }
                    }
                }
                .atlasCard()
            }
        }
    }
}

// MARK: - Hero

private struct CaloriesHero: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let ctx = app.context
        let left = Double(ctx.targets.kcal) - ctx.eaten.kcal
        let pct = ctx.targets.kcal > 0 ? ctx.eaten.kcal / Double(ctx.targets.kcal) : 0
        HStack(alignment: .center, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(Fmt.kcal(abs(left)))
                    .textStyle(.metricXL)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText(value: left))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(left >= 0 ? "kcal left" : "kcal over")
                    .textStyle(.headline)
                    .foregroundStyle(left >= 0 ? Theme.Palette.textSecondary : Theme.Palette.scoreLow)
                Text("\(Fmt.kcal(ctx.eaten.kcal)) eaten of \(Fmt.kcal(Double(ctx.targets.kcal)))")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.top, Theme.Space.xxs)
            }
            Spacer(minLength: 0)
            ScoreRing(progress: pct, color: Theme.Palette.fuel, diameter: 112) {
                Image(systemName: "flame.fill")
                    .icon(Theme.Icon.hero, weight: .regular)
                    .foregroundStyle(Theme.Palette.fuel)
            }
        }
        .atlasCard(padding: Theme.Space.hero)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(abs(left))) calories \(left >= 0 ? "left" : "over"). \(Int(ctx.eaten.kcal)) eaten of \(ctx.targets.kcal).")
        .accessibilityIdentifier("caloriesHero")
    }
}

private struct MacroTrio: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let ctx = app.context
        HStack(spacing: Theme.Space.m) {
            MacroBar(label: "Protein", value: ctx.eaten.protein, target: Double(ctx.targets.proteinG), color: Theme.Palette.fuel)
            MacroBar(label: "Carbs", value: ctx.eaten.carbs, target: Double(ctx.targets.carbsG), color: Theme.Palette.sleep)
            MacroBar(label: "Fat", value: ctx.eaten.fat, target: Double(ctx.targets.fatG), color: Theme.Palette.recovery)
        }
        .atlasCard()
    }
}

private struct EatingWindowCard: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let w = app.context.eatingWindow {
            let cal = Calendar.current
            let open = UnitConvert.timeToMinutes(w.opens, calendar: cal)
            let close = UnitConvert.timeToMinutes(w.closes, calendar: cal)
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    MicroLabel("Eating window")
                    Spacer()
                    Text("\(Fmt.clock(w.opens)) – \(Fmt.clock(w.closes))")
                        .textStyle(.footnote)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                HStack(spacing: Theme.Space.xs) {
                    Circle().fill(w.isOpen ? Theme.Palette.recovery : Theme.Palette.textTertiary).frame(width: 8, height: 8)
                    Text(w.isOpen ? "Window closes in \(Fmt.duration(minutes: w.minutesToNextChange))" : "Opens in \(Fmt.duration(minutes: w.minutesToNextChange))")
                        .textStyle(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                EatingWindowBar(openMinutes: open, closeMinutes: close, nowMinutes: UnitConvert.timeToMinutes(app.context.now, calendar: cal))
            }
            .atlasCard()
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Meal row

struct MealRow: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            MealThumbnail(meal: meal)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title)
                    .textStyle(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text("\(meal.mealType.title) · \(Fmt.clock(meal.date))")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text("P \(Int(meal.totalProtein.rounded())) · C \(Int(meal.totalCarbs.rounded())) · F \(Int(meal.totalFat.rounded()))")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .monospacedDigit()
            }
            Spacer(minLength: Theme.Space.xs)
            VStack(alignment: .trailing, spacing: 0) {
                Text(Fmt.kcal(meal.totalKcal))
                    .textStyle(.metricS)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("kcal").textStyle(.footnote).foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.vertical, Theme.Space.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct MealThumbnail: View {
    let meal: MealEntry
    var size: CGFloat = Theme.Size.thumbnail

    var body: some View {
        Group {
            if let data = meal.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(meal.items.first?.emoji ?? "🍽️")
                    .textStyle(.title)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Palette.fill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: Theme.Radius.small, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - 7-day chart

private struct WeekChart: View {
    let meals: [MealEntry]
    let now: Date
    let target: Int

    private struct DayTotal: Identifiable {
        let day: Date
        let kcal: Double
        let protein: Double
        var id: Date { day }
    }

    private var days: [DayTotal] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let m = meals.filter { cal.isDate($0.date, inSameDayAs: day) }
            return DayTotal(day: day, kcal: m.reduce(0) { $0 + $1.totalKcal }, protein: m.reduce(0) { $0 + $1.totalProtein })
        }
    }

    var body: some View {
        let data = days
        let logged = data.filter { $0.kcal > 0 }
        let avg = logged.isEmpty ? 0 : logged.reduce(0) { $0 + $1.kcal } / Double(logged.count)
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    MicroLabel("7-day average")
                    MetricText(value: Fmt.kcal(avg), unit: "kcal", style: .metricM)
                }
                Spacer()
                HStack(spacing: Theme.Space.xxs) {
                    RoundedRectangle(cornerRadius: 1).fill(Theme.Palette.textTertiary).frame(width: 12, height: 2)
                    Text("Target").textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Chart {
                ForEach(data) { d in
                    BarMark(x: .value("Day", d.day, unit: .day), y: .value("kcal", d.kcal), width: .ratio(0.55))
                        .foregroundStyle(Calendar.current.isDate(d.day, inSameDayAs: now) ? Theme.Palette.fuel : Theme.Palette.fuel.opacity(0.45))
                        .clipShape(.rect(cornerRadius: Theme.Radius.tiny / 2))
                }
                if target > 0 {
                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Theme.Palette.hairline)
                    AxisValueLabel().foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .frame(height: 160)
            .accessibilityLabel("Calories over the last 7 days")
        }
        .atlasCard(padding: Theme.Space.hero)
    }
}
