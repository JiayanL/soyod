import Foundation

/// App-wide clock. All engine/context code must use `AppClock.now` so the
/// `-AtlasNow <ISO8601>` launch argument can pin "now" for demos and tests.
nonisolated enum AppClock {
    private static let anchor: (fixed: Date, launchedAt: Date)? = {
        let args = UserDefaults.standard
        guard let raw = args.string(forKey: "AtlasNow"), !raw.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let fixed = fmt.date(from: raw) else { return nil }
        return (fixed, Date())
    }()

    /// Current time: `Date()`, or the fixed `-AtlasNow` time plus elapsed
    /// time since launch when the argument is set.
    static var now: Date {
        guard let anchor else { return Date() }
        return anchor.fixed.addingTimeInterval(Date().timeIntervalSince(anchor.launchedAt))
    }
}
