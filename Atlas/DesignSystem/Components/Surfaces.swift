import SwiftUI

/// Standard card: `surface` fill, hairline border in dark, soft shadow in light.
struct AtlasCardModifier: ViewModifier {
    var padding: CGFloat = Theme.Space.card
    var radius: CGFloat = Theme.Radius.card
    var fill: Color = Theme.Palette.surface
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Stroke.hairline)
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 16, x: 0, y: 4)
    }
}

extension View {
    func atlasCard(padding: CGFloat = Theme.Space.card, radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(AtlasCardModifier(padding: padding, radius: radius))
    }

    func atlasElevatedCard(padding: CGFloat = Theme.Space.card, radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(AtlasCardModifier(padding: padding, radius: radius, fill: Theme.Palette.surfaceElevated))
    }

    /// Screen background with the app canvas color.
    func atlasScreenBackground() -> some View {
        background(Theme.Palette.bg.ignoresSafeArea())
    }

    /// Standard horizontal gutter.
    func gutter() -> some View {
        padding(.horizontal, Theme.Space.gutter)
    }
}

/// Inset hairline divider.
struct Hairline: View {
    var leading: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(Theme.Palette.hairline)
            .frame(height: Theme.Stroke.hairline)
            .padding(.leading, leading)
            .accessibilityHidden(true)
    }
}

/// Atmospheric header gradient tinted by the day's state (DESIGN §2 "Atmosphere").
struct AtmosphereBackground: View {
    var tint: Color
    var height: CGFloat = 420
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strength = scheme == .dark ? 0.30 : 0.22
        ZStack {
            Theme.Palette.bg
            if #available(iOS 18.0, *), !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 15)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    mesh(t: t, strength: strength)
                }
            } else if #available(iOS 18.0, *) {
                mesh(t: 0, strength: strength)
            } else {
                LinearGradient(
                    colors: [tint.opacity(strength), tint.opacity(strength * 0.3), .clear],
                    startPoint: .topLeading, endPoint: .bottom
                )
            }
            LinearGradient(colors: [.clear, Theme.Palette.bg], startPoint: .center, endPoint: .bottom)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @available(iOS 18.0, *)
    private func mesh(t: Double, strength: Double) -> some View {
        let dx = Float(sin(t / 7) * 0.12)
        let dy = Float(cos(t / 9) * 0.08)
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5 + dx, 0], [1, 0],
                [0, 0.45 - dy], [0.55 - dx, 0.4 + dy], [1, 0.5 + dy],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                tint.opacity(strength), tint.opacity(strength * 0.55), Theme.Palette.sleep.opacity(strength * 0.5),
                tint.opacity(strength * 0.45), tint.opacity(strength * 0.2), Theme.Palette.sleep.opacity(strength * 0.2),
                .clear, .clear, .clear
            ]
        )
    }
}

extension View {
    /// Fades scrolling content out behind floating bottom CTAs so they never sit on top of text.
    func bottomBarScrim() -> some View {
        background(alignment: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Theme.Palette.bg.opacity(0), Theme.Palette.bg],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: Theme.Space.xxl)
                Theme.Palette.bg
            }
            .padding(.top, -Theme.Space.xxl)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
