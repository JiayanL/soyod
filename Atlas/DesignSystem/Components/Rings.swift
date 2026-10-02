import SwiftUI

/// Thick round-capped progress ring (lineWidth ≈ 10% of diameter), 14% track, animated fill.
struct ScoreRing<Center: View>: View {
    var progress: Double
    var color: Color
    var diameter: CGFloat
    var lineWidth: CGFloat? = nil
    @ViewBuilder var center: () -> Center

    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = lineWidth ?? max(4, diameter * 0.1)
        ZStack {
            Circle()
                .stroke(color.opacity(Theme.Stroke.trackOpacity), lineWidth: width)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, shown)))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .padding(width / 2)
        .frame(width: diameter, height: diameter)
        .onAppear {
            if reduceMotion { shown = progress } else {
                withAnimation(Theme.Motion.fill.delay(0.1)) { shown = progress }
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(reduceMotion ? nil : Theme.Motion.standard) { shown = new }
        }
    }
}

/// A labelled pillar ring (Bevel/WHOOP top row): ring with value, micro label beneath.
struct PillarRing: View {
    let label: String
    let valueText: String
    var unit: String = "%"
    let progress: Double
    let color: Color
    var diameter: CGFloat = 92

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            ScoreRing(progress: progress, color: color, diameter: diameter) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(valueText)
                        .textStyle(.metricM)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit)
                            .textStyle(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Text(label)
                .textStyle(.micro)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(valueText)\(unit)")
    }
}
