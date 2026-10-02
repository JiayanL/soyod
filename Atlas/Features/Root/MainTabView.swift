import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var app = app
        @Bindable var router = router
        TabView(selection: $app.selectedTab) {
            CoachScreen()
                .tabItem { Label("Coach", systemImage: "sparkles") }
                .tag(AppTab.coach)
            FuelScreen()
                .tabItem { Label("Fuel", systemImage: "fork.knife") }
                .tag(AppTab.fuel)
            TrainScreen()
                .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }
                .tag(AppTab.train)
            SleepScreen()
                .tabItem { Label("Sleep", systemImage: "moon.stars.fill") }
                .tag(AppTab.sleep)
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)
        }
        .sensoryFeedback(.selection, trigger: app.selectedTab)
        .sheet(item: $router.sheet) { sheet in
            SheetHost(sheet: sheet)
        }
        .onAppear { consumeRoute() }
        .onChange(of: app.pendingRoute) { _, _ in consumeRoute() }
    }

    private func consumeRoute() {
        guard let route = app.pendingRoute else { return }
        app.pendingRoute = nil
        router.apply(route, app: app)
    }
}

/// Renders every modal sheet in one place so any tab or deep link can present it.
struct SheetHost: View {
    let sheet: AppSheet

    var body: some View {
        switch sheet {
        case .memory:
            MemorySheet()
                .presentationDetents([.large])
                .presentationCornerRadius(Theme.Radius.sheet)
        case .quickLog:
            QuickLogSheet()
                .presentationDetents([.height(360)])
                .presentationCornerRadius(Theme.Radius.sheet)
                .presentationBackground(.thinMaterial)
        case .logMeal(let type):
            LogMealSheet(initialType: type)
                .presentationCornerRadius(Theme.Radius.sheet)
        case .snap:
            SnapPickerSheet()
                .presentationCornerRadius(Theme.Radius.sheet)
        case .snapReview(let input):
            SnapReviewView(image: input.image)
                .presentationCornerRadius(Theme.Radius.sheet)
                .interactiveDismissDisabled()
        case .mealDetail(let id):
            MealDetailSheet(mealID: id)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(Theme.Radius.sheet)
        case .logger(let session):
            WorkoutLoggerView(session: session)
                .interactiveDismissDisabled()
        case .workoutSummary(let result):
            WorkoutSummaryView(result: result)
                .presentationCornerRadius(Theme.Radius.sheet)
        case .cardio:
            CardioLogSheet()
                .presentationCornerRadius(Theme.Radius.sheet)
        case .manualSleep:
            ManualSleepSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(Theme.Radius.sheet)
        case .measurement:
            MeasurementSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(Theme.Radius.sheet)
        case .settings:
            SettingsView()
                .presentationCornerRadius(Theme.Radius.sheet)
        case .integrations:
            IntegrationsView()
                .presentationCornerRadius(Theme.Radius.sheet)
        }
    }
}

/// Toolbar "+" quick-log entry used on every tab.
struct QuickLogToolbarButton: View {
    @Environment(Router.self) private var router

    var body: some View {
        Button {
            router.sheet = .quickLog
        } label: {
            Image(systemName: "plus")
                .icon(Theme.Icon.regular)
        }
        .accessibilityLabel("Quick log")
        .accessibilityIdentifier("quickLog")
    }
}

struct QuickLogSheet: View {
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    private let items: [(String, String, String, Color, AppSheet)] = [
        ("Snap meal", "Photo → macros", "camera.fill", Theme.Palette.fuel, .snap),
        ("Describe meal", "Type it, search or quick add", "text.bubble.fill", Theme.Palette.fuel, .logMeal(nil)),
        ("Log workout", "Strength, cardio or sport", "figure.strengthtraining.traditional", Theme.Palette.train, .logger(nil)),
        ("Log sleep", "Bedtime, wake, quality", "moon.stars.fill", Theme.Palette.sleep, .manualSleep),
        ("Measurement", "Update your goal metric", "ruler.fill", Theme.Palette.accent, .measurement)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Log")
                .textStyle(.serifTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.top, Theme.Space.xl)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.s), GridItem(.flexible(), spacing: Theme.Space.s)], spacing: Theme.Space.s) {
                ForEach(items, id: \.0) { item in
                    Button {
                        let next = item.4
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            router.sheet = next
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            IconDisk(symbol: item.2, color: item.3)
                            Text(item.0)
                                .textStyle(.headline)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(item.1)
                                .textStyle(.footnote)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Space.s)
                        .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.inner, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .gutter()
    }
}
