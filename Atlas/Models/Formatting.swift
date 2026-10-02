import Foundation

/// Display formatting helpers. Canonical units: length cm, mass kg, time seconds.
nonisolated enum Fmt {

    // MARK: - Conversions

    static func cmToIn(_ cm: Double) -> Double { cm / 2.54 }
    static func inToCm(_ inch: Double) -> Double { inch * 2.54 }
    static func kgToLb(_ kg: Double) -> Double { kg * 2.2046226218 }
    static func lbToKg(_ lb: Double) -> Double { lb / 2.2046226218 }
    static func mToMi(_ m: Double) -> Double { m / 1609.344 }
    static func mToKm(_ m: Double) -> Double { m / 1000 }

    // MARK: - Metric values

    /// The unit suffix for a metric in a unit system ("" when baked into the string).
    static func metricUnit(metric: GoalMetric, units: UnitSystem, customUnit: String? = nil) -> String {
        switch metric.dimension {
        case .length: return units == .imperial ? "″" : " cm"
        case .mass: return units == .imperial ? " lb" : " kg"
        case .time: return ""
        case .custom: return customUnit.map { " \($0)" } ?? ""
        }
    }

    /// Number (with unit for length/time styles) for a canonical value.
    static func metricValue(_ canonical: Double, metric: GoalMetric, units: UnitSystem) -> String {
        switch metric.dimension {
        case .length:
            if units == .imperial {
                return String(format: "%.1f″", cmToIn(canonical))
            }
            let cm = canonical
            return cm == cm.rounded() ? String(format: "%.0f cm", cm) : String(format: "%.1f cm", cm)
        case .mass:
            let v = units == .imperial ? kgToLb(canonical) : canonical
            return v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
        case .time:
            return clockTime(seconds: canonical)
        case .custom:
            return trimmed(canonical)
        }
    }

    /// Combined value + unit ("24.5″", "185 lb", "19:42", "12 reps").
    static func metric(_ canonical: Double, metric: GoalMetric, units: UnitSystem, customUnit: String? = nil) -> String {
        switch metric.dimension {
        case .length, .time:
            return metricValue(canonical, metric: metric, units: units)
        case .mass:
            return metricValue(canonical, metric: metric, units: units) + metricUnit(metric: metric, units: units)
        case .custom:
            return trimmed(canonical) + metricUnit(metric: metric, units: units, customUnit: customUnit)
        }
    }

    /// Display value -> canonical, for input fields.
    static func canonical(fromDisplay display: Double, metric: GoalMetric, units: UnitSystem) -> Double {
        switch metric.dimension {
        case .length: return units == .imperial ? inToCm(display) : display
        case .mass: return units == .imperial ? lbToKg(display) : display
        case .time, .custom: return display
        }
    }

    // MARK: - Time / counts

    /// 462 -> "7h 42m"
    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// Seconds -> "7h 42m"
    static func duration(seconds: Int) -> String { duration(minutes: seconds / 60) }

    /// "7:30 PM" (locale-aware).
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: .current)
        return f.string(from: date)
    }

    /// Seconds -> "19:42" (m:ss, h:mm:ss when needed).
    static func clockTime(seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// 1234 -> "1,234"
    static func kcal(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    /// 112.4 -> "112"
    static func grams(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    /// 84 kg -> "185 lb" / "84 kg"
    static func weight(kg: Double, units: UnitSystem) -> String {
        if units == .imperial {
            return String(format: "%.0f lb", kgToLb(kg))
        }
        return kg == kg.rounded() ? String(format: "%.0f kg", kg) : String(format: "%.1f kg", kg)
    }

    /// 5000 m -> "3.11 mi" / "5.00 km"
    static func distance(m: Double, units: UnitSystem) -> String {
        if units == .imperial {
            return String(format: "%.2f mi", mToMi(m))
        }
        return String(format: "%.2f km", mToKm(m))
    }

    /// 300 s/km -> "8:03 /mi" / "5:00 /km"
    static func pace(secPerKm: Double, units: UnitSystem) -> String {
        let spu = units == .imperial ? secPerKm * 1.609344 : secPerKm
        let suffix = units == .imperial ? "/mi" : "/km"
        return "\(clockTime(seconds: spu)) \(suffix)"
    }

    /// "Today" / "Yesterday" / "Mon".
    static func relativeDay(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    static func date(_ date: Date, format: String = "MMM d") -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }

    // MARK: - Private

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    /// Drops ".0" from whole numbers.
    private static func trimmed(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1e15 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.1f", v)
    }
}
