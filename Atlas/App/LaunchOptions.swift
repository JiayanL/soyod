import Foundation

/// Routes the app can deep-link / launch directly into.
/// Parsed from `-AtlasScreen <route>` and `atlas://<route>` URLs.
nonisolated enum LaunchRoute: String, CaseIterable, Sendable {
    case coach, chat, chatAction, memory
    case fuel, logMeal, snapReview
    case train, logger, workoutSummary, cardioLog
    case sleep, manualSleep
    case progress, measurement
    case settings, integrations
    case onbWelcome, onbGoal, onbBaseline, onbAbout, onbFuel, onbConnect, onbPlan

    init?(url: URL) {
        guard url.scheme == "atlas" else { return nil }
        // atlas://coach  or  atlas:///coach
        let raw = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.init(rawValue: raw)
    }
}

/// Parsed launch arguments (UserDefaults from ProcessInfo arguments).
nonisolated struct LaunchOptions: Sendable {
    var sampleData = false
    var resetOnboarding = false
    var denyPermissions = false
    var uiTest = false
    var screen: LaunchRoute?
    /// Fixed "now" supplied via -AtlasNow (also see AppClock).
    var fixedNow: Date?

    static let current = LaunchOptions()

    init(userDefaults: UserDefaults = .standard) {
        sampleData = userDefaults.bool(forKey: "AtlasSampleData")
        resetOnboarding = userDefaults.bool(forKey: "AtlasResetOnboarding")
        denyPermissions = userDefaults.bool(forKey: "AtlasDenyPermissions")
        uiTest = userDefaults.bool(forKey: "AtlasUITest")
        if let raw = userDefaults.string(forKey: "AtlasScreen") {
            screen = LaunchRoute(rawValue: raw)
        }
        if let raw = userDefaults.string(forKey: "AtlasNow") {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = .current
            fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            fixedNow = fmt.date(from: raw)
        }
    }
}
