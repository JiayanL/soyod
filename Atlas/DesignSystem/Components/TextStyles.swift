import SwiftUI

/// UPPERCASE letter-spaced label over numbers.
struct MicroLabel: View {
    let text: String
    var color: Color = Theme.Palette.textSecondary

    init(_ text: String, color: Color = Theme.Palette.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .textStyle(.micro)
            .foregroundStyle(color)
    }
}

/// Numbers with smaller secondary units: "7h 42m", "1,240 kcal".
struct MetricText: View {
    struct Part: Hashable {
        let value: String
        let unit: String
    }

    let parts: [Part]
    var style: AtlasTextStyle = .metricL
    var unitStyle: AtlasTextStyle = .callout
    var color: Color = Theme.Palette.textPrimary

    init(_ parts: [Part], style: AtlasTextStyle = .metricL, unitStyle: AtlasTextStyle = .callout, color: Color = Theme.Palette.textPrimary) {
        self.parts = parts
        self.style = style
        self.unitStyle = unitStyle
        self.color = color
    }

    init(value: String, unit: String, style: AtlasTextStyle = .metricL, unitStyle: AtlasTextStyle = .callout, color: Color = Theme.Palette.textPrimary) {
        self.init([Part(value: value, unit: unit)], style: style, unitStyle: unitStyle, color: color)
    }

    /// "7h 42m" from minutes.
    static func duration(minutes: Int, style: AtlasTextStyle = .metricL, unitStyle: AtlasTextStyle = .callout) -> MetricText {
        let h = max(0, minutes) / 60
        let m = max(0, minutes) % 60
        return MetricText([Part(value: "\(h)", unit: "h"), Part(value: "\(m)", unit: "m")], style: style, unitStyle: unitStyle)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                Text(part.value)
                    .textStyle(style)
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                if !part.unit.isEmpty {
                    Text(part.unit)
                        .textStyle(unitStyle)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.trailing, index < parts.count - 1 ? Theme.Space.xxs : 0)
                }
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(parts.map { "\($0.value) \($0.unit)" }.joined(separator: " "))
    }
}

/// Section title row with an optional trailing link.
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .textStyle(.title)
                .foregroundStyle(Theme.Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Theme.Space.s)
            if let trailing, let action {
                Button(trailing, action: action)
                    .textStyle(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .buttonStyle(.plain)
                    .frame(minHeight: Theme.Size.minTap)
            }
        }
    }
}

/// A rounded tinted icon disk (pillar glyph in a circle).
struct IconDisk: View {
    let symbol: String
    let color: Color
    var size: CGFloat = Theme.Size.directiveIcon

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: .circle)
            .accessibilityHidden(true)
    }
}

/// Capsule status chip: "Vertical 26.0″ → 30″ · 62 days · On track".
struct StatusChip: View {
    let text: String
    var dot: Color? = nil
    var showsChevron = false

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            if let dot {
                Circle().fill(dot).frame(width: 8, height: 8)
            }
            Text(text)
                .textStyle(.callout)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Space.s)
        .padding(.vertical, Theme.Space.xs)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Stroke.hairline))
    }
}
