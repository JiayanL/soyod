import SwiftUI

/// Solid capsule in `textPrimary` with a `bg`-colored label (white pill on black, black pill on paper).
struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = true
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(compact ? .callout : .headline)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.Palette.onPrimary)
            .padding(.horizontal, compact ? Theme.Space.m : Theme.Space.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: compact ? 40 : Theme.Size.primaryButtonHeight)
            .background(Theme.Palette.textPrimary, in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

/// Volt capsule — reserved for the single hero CTA on onboarding.
struct HeroButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.headline)
            .foregroundStyle(Theme.Palette.onAccent)
            .padding(.horizontal, Theme.Space.xl)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Size.primaryButtonHeight)
            .background(Theme.Palette.accentFill, in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

/// Outline hairline capsule.
struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth = true
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(compact ? .callout : .headline)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, compact ? Theme.Space.m : Theme.Space.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: compact ? 40 : Theme.Size.primaryButtonHeight)
            .background(Theme.Palette.fill.opacity(configuration.isPressed ? 1 : 0.0001), in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.Palette.fillStrong, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

/// Small filled chip (suggestions, filters, inline actions).
struct ChipButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.callout)
            .fontWeight(.medium)
            .lineLimit(1)
            .foregroundStyle(selected ? Theme.Palette.onPrimary : (tint ?? Theme.Palette.textPrimary))
            .padding(.horizontal, Theme.Space.s)
            .padding(.vertical, Theme.Space.xs)
            .frame(minHeight: 36)
            .background(selected ? Theme.Palette.textPrimary : Theme.Palette.fill, in: .capsule)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(.capsule)
    }
}

/// 36pt circular icon button.
struct IconButton: View {
    let symbol: String
    let label: String
    var filled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: Theme.Size.iconButton, height: Theme.Size.iconButton)
                .background(filled ? Theme.Palette.fill : .clear, in: .circle)
                .contentShape(.rect)
                .frame(minWidth: Theme.Size.minTap, minHeight: Theme.Size.minTap)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// "DIVE INTO MY SLEEP →" style text link.
struct TextLink: View {
    let title: String
    var color: Color = Theme.Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.xxs) {
                Text(title).textStyle(.micro)
                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(color)
            .frame(minHeight: Theme.Size.minTap)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var atlasPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var atlasPrimaryCompact: PrimaryButtonStyle { PrimaryButtonStyle(fullWidth: false, compact: true) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var atlasSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var atlasSecondaryCompact: SecondaryButtonStyle { SecondaryButtonStyle(fullWidth: false, compact: true) }
}

extension ButtonStyle where Self == HeroButtonStyle {
    static var atlasHero: HeroButtonStyle { HeroButtonStyle() }
}

extension ButtonStyle where Self == ChipButtonStyle {
    static var atlasChip: ChipButtonStyle { ChipButtonStyle() }
}
