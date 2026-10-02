import SwiftUI

/// Rounded 8pt progress bar with "112 / 180 g" label (DESIGN §5 MacroBar).
struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double
    var unit: String = "g"
    let color: Color

    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double { target > 0 ? min(1, value / target) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(label)
                .textStyle(.micro)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Int(value.rounded()), format: .number)
                    .textStyle(.metricM)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText())
                Text("/ \(Int(target.rounded()))\(unit)")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            ProgressTrack(fraction: shown, color: color)
        }
        .onAppear {
            if reduceMotion { shown = fraction } else { withAnimation(Theme.Motion.fill.delay(0.15)) { shown = fraction } }
        }
        .onChange(of: fraction) { _, new in withAnimation(Theme.Motion.standard) { shown = new } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(value.rounded())) of \(Int(target.rounded())) \(unit)")
    }
}

/// Simple capsule track.
struct ProgressTrack: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(Theme.Stroke.trackOpacity))
                Capsule().fill(color)
                    .frame(width: max(height, proxy.size.width * min(1, max(0, fraction))))
                    .opacity(fraction <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// 24h timeline with the eating window highlighted and a "now" needle.
struct EatingWindowBar: View {
    /// Minutes after midnight.
    let openMinutes: Int
    let closeMinutes: Int
    let nowMinutes: Int

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            GeometryReader { proxy in
                let w = proxy.size.width
                let x = { (m: Int) -> CGFloat in CGFloat(m) / 1440 * w }
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.fill)
                    windowShape(w: w, x: x)
                    // now needle
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.Palette.textPrimary)
                        .frame(width: 3, height: 22)
                        .offset(x: min(max(0, x(nowMinutes) - 1.5), w - 3))
                }
            }
            .frame(height: 22)
            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    if hour > 0 { Spacer(minLength: 0) }
                    Text(hourLabel(hour))
                        .textStyle(.micro)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func windowShape(w: CGFloat, x: (Int) -> CGFloat) -> some View {
        if closeMinutes > openMinutes {
            Capsule().fill(Theme.Palette.fuel)
                .frame(width: max(8, x(closeMinutes) - x(openMinutes)), height: 14)
                .offset(x: x(openMinutes))
        } else {
            // wraps past midnight
            Capsule().fill(Theme.Palette.fuel)
                .frame(width: max(8, x(closeMinutes)), height: 14)
            Capsule().fill(Theme.Palette.fuel)
                .frame(width: max(8, w - x(openMinutes)), height: 14)
                .offset(x: x(openMinutes))
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0, 24: "12a"
        case 12: "12p"
        case let h where h < 12: "\(h)a"
        default: "\(hour - 12)p"
        }
    }
}
