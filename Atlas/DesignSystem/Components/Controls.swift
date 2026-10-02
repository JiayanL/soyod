import SwiftUI

/// Capsule segmented control (7D / 30D / 90D).
struct SegmentedPills<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { option in
                let isOn = option.0 == selection
                Button {
                    withAnimation(Theme.Motion.snappy) { selection = option.0 }
                } label: {
                    Text(option.1)
                        .textStyle(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(isOn ? Theme.Palette.onPrimary : Theme.Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, Theme.Space.s)
                        .frame(minHeight: 32)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isOn {
                                Capsule().fill(Theme.Palette.textPrimary).matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(Theme.Space.xxs - 1)
        .background(Theme.Palette.fill, in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// "−  1×  +" portion / value stepper.
struct QuantityStepper: View {
    @Binding var value: Double
    var step: Double = 0.5
    var range: ClosedRange<Double> = 0.5...3
    var format: (Double) -> String = { v in
        v == v.rounded() ? "\(Int(v))×" : String(format: "%.1f×", v)
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", label: "Decrease") { value = max(range.lowerBound, value - step) }
                .disabled(value <= range.lowerBound)
            Text(format(value))
                .textStyle(.metricS)
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(minWidth: 44)
                .contentTransition(.numericText())
            stepButton("plus", label: "Increase") { value = min(range.upperBound, value + step) }
                .disabled(value >= range.upperBound)
        }
        .background(Theme.Palette.fill, in: .capsule)
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .combine)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.Motion.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 36, height: 36)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Designed empty state for lists.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var ctaTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(width: 56, height: 56)
                .background(Theme.Palette.fill, in: .circle)
            Text(title)
                .textStyle(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(message)
                .textStyle(.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let ctaTitle, let action {
                Button(ctaTitle, action: action)
                    .buttonStyle(.atlasPrimaryCompact)
                    .padding(.top, Theme.Space.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
        .padding(.horizontal, Theme.Space.m)
    }
}

/// Hairline progress bar used at the top of onboarding.
struct StepProgress: View {
    let step: Int
    let total: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.fillStrong)
                Capsule().fill(Theme.Palette.textPrimary)
                    .frame(width: proxy.size.width * CGFloat(step) / CGFloat(max(1, total)))
            }
        }
        .frame(height: 3)
        .animation(Theme.Motion.standard, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step) of \(total)")
    }
}
