import SwiftUI

/// 2-column grid metric tile.
struct MetricTile: View {
    let symbol: String
    let label: String
    let value: String
    var unit: String = ""
    var delta: String? = nil
    var deltaPositive: Bool? = nil
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                MicroLabel(label)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                MetricText(value: value, unit: unit, style: .metricL, unitStyle: .callout)
                Spacer(minLength: 0)
                if let delta {
                    DeltaLabel(text: delta, positive: deltaPositive)
                }
            }
        }
        .atlasCard()
        .accessibilityElement(children: .combine)
    }
}

/// ▲ / ▼ delta with semantic color.
struct DeltaLabel: View {
    let text: String
    var positive: Bool?

    var body: some View {
        HStack(spacing: 2) {
            if let positive {
                Image(systemName: positive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text).textStyle(.footnote).fontWeight(.semibold)
        }
        .foregroundStyle(positive == nil ? Theme.Palette.textSecondary : (positive! ? Theme.Palette.scoreHigh : Theme.Palette.scoreLow))
        .lineLimit(1)
    }
}

/// WHOOP-style metric row: icon, label, mini bar, value.
struct MetricRow: View {
    let symbol: String
    let label: String
    let value: String
    var fraction: Double? = nil
    var color: Color = Theme.Palette.textPrimary
    var delta: String? = nil
    var deltaPositive: Bool? = nil

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 20)
            Text(label)
                .textStyle(.micro)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: Theme.Space.xs)
            if let fraction {
                ProgressTrack(fraction: fraction, color: color, height: 4)
                    .frame(width: 56)
            }
            if let delta {
                DeltaLabel(text: delta, positive: deltaPositive)
            }
            Text(value)
                .textStyle(.metricS)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.vertical, Theme.Space.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// Whoop/Oura-style insight: serif headline, body, text link.
struct InsightCard: View {
    var eyebrow: String? = nil
    let headline: String
    let message: String
    var linkTitle: String? = nil
    var linkColor: Color = Theme.Palette.accent
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if let eyebrow { MicroLabel(eyebrow) }
            Text(headline)
                .textStyle(.serifTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .textStyle(.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let linkTitle, let action {
                TextLink(title: linkTitle, color: linkColor, action: action)
                    .padding(.top, -Theme.Space.xxs)
                    .padding(.bottom, -Theme.Space.s)
            }
        }
        .atlasCard(padding: Theme.Space.hero)
    }
}

/// Game Plan item (DESIGN §5 DirectiveRow).
struct DirectiveRow: View {
    let index: Int
    let symbol: String
    let color: Color
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var actionDone = false
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            IconDisk(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(title)
                    .textStyle(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .textStyle(.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let onAction {
                    Button(action: onAction) {
                        HStack(spacing: Theme.Space.xxs) {
                            if actionDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Text(actionDone ? "Done" : actionTitle)
                        }
                    }
                    .buttonStyle(ChipButtonStyle(tint: actionDone ? Theme.Palette.scoreHigh : Theme.Palette.textPrimary))
                    .disabled(actionDone)
                    .padding(.top, Theme.Space.xs)
                    .animation(Theme.Motion.standard, value: actionDone)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index). \(title). \(detail)")
    }
}

/// Agentic proposal card: proposed → in progress → done.
struct ActionCardView: View {
    enum Phase: Equatable { case proposed, working, done, dismissed }

    let symbol: String
    let provider: String
    let title: String
    let subtitle: String
    var details: [String] = []
    let primaryTitle: String
    var doneTitle: String = "Done"
    var resultNote: String? = nil
    let phase: Phase
    let onPrimary: () -> Void
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                MicroLabel(provider, color: Theme.Palette.textSecondary)
                Spacer()
                if phase == .proposed, let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
            }
            .foregroundStyle(Theme.Palette.textSecondary)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(title)
                    .textStyle(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .textStyle(.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !details.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    ForEach(details, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                            Circle().fill(Theme.Palette.textTertiary).frame(width: 4, height: 4)
                                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 4 }
                            Text(line)
                                .textStyle(.footnote)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Group {
                switch phase {
                case .proposed:
                    Button(primaryTitle, action: onPrimary)
                        .buttonStyle(PrimaryButtonStyle(fullWidth: true, compact: true))
                case .working:
                    HStack(spacing: Theme.Space.xs) {
                        ProgressView().tint(Theme.Palette.textPrimary)
                        Text("Working on it").textStyle(.callout).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                case .done:
                    HStack(spacing: Theme.Space.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Palette.scoreHigh)
                            .symbolEffect(.bounce, value: phase)
                        Text(resultNote ?? doneTitle)
                            .textStyle(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                case .dismissed:
                    Text("Dismissed").textStyle(.callout).foregroundStyle(Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                }
            }
            .animation(Theme.Motion.standard, value: phase)
        }
        .atlasCard()
        .sensoryFeedback(.success, trigger: phase == .done)
        .accessibilityElement(children: .contain)
    }
}
