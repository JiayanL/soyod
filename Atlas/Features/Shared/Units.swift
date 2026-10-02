import Foundation

/// Canonical ↔ display conversion for input fields (canonical: cm, kg, seconds).
enum UnitConvert {
    static let cmPerInch = 2.54
    static let lbPerKg = 2.2046226218

    static func display(_ canonical: Double, dimension: MetricDimension, units: UnitSystem) -> Double {
        switch (dimension, units) {
        case (.length, .imperial): canonical / cmPerInch
        case (.mass, .imperial): canonical * lbPerKg
        default: canonical
        }
    }

    static func canonical(_ display: Double, dimension: MetricDimension, units: UnitSystem) -> Double {
        switch (dimension, units) {
        case (.length, .imperial): display * cmPerInch
        case (.mass, .imperial): display / lbPerKg
        default: display
        }
    }

    static func unit(_ dimension: MetricDimension, units: UnitSystem, custom: String = "") -> String {
        switch (dimension, units) {
        case (.length, .imperial): "in"
        case (.length, .metric): "cm"
        case (.mass, .imperial): "lb"
        case (.mass, .metric): "kg"
        case (.time, _): "min:sec"
        case (.custom, _): custom
        }
    }

    static func weightDisplay(kg: Double, units: UnitSystem) -> Double { units == .imperial ? kg * lbPerKg : kg }
    static func weightCanonical(_ v: Double, units: UnitSystem) -> Double { units == .imperial ? v / lbPerKg : v }
    static func weightUnit(_ units: UnitSystem) -> String { units == .imperial ? "lb" : "kg" }

    static func distanceDisplay(m: Double, units: UnitSystem) -> Double { units == .imperial ? m / 1609.344 : m / 1000 }
    static func distanceCanonical(_ v: Double, units: UnitSystem) -> Double { units == .imperial ? v * 1609.344 : v * 1000 }
    static func distanceUnit(_ units: UnitSystem) -> String { units == .imperial ? "mi" : "km" }

    static func minutesToTime(_ minutes: Int, on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: minutes / 60 % 24, minute: minutes % 60, second: 0, of: day) ?? day
    }

    static func timeToMinutes(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func number(_ v: Double, decimals: Int = 1) -> String {
        v.formatted(.number.precision(.fractionLength(0...decimals)))
    }
}
