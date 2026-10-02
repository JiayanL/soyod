import SwiftUI
import UIKit

/// Atlas design tokens. Feature views must only use these (DESIGN.md §2–§4).
enum Theme {
    // MARK: Color
    enum Palette {
        static let bg = Color(light: 0xF4F3EF, dark: 0x07080B)
        static let surface = Color(light: 0xFFFFFF, dark: 0x12141A)
        static let surfaceElevated = Color(light: 0xFFFFFF, dark: 0x1A1D25)
        /// Inputs, chips, tracks inside cards.
        static let fill = Color(light: 0x000000, lightAlpha: 0.045, dark: 0xFFFFFF, darkAlpha: 0.07)
        static let fillStrong = Color(light: 0x000000, lightAlpha: 0.08, dark: 0xFFFFFF, darkAlpha: 0.12)
        static let hairline = Color(light: 0x000000, lightAlpha: 0.07, dark: 0xFFFFFF, darkAlpha: 0.08)

        static let textPrimary = Color(light: 0x0E0F12, dark: 0xF5F5F2)
        static let textSecondary = Color(light: 0x000000, lightAlpha: 0.56, dark: 0xFFFFFF, darkAlpha: 0.62)
        static let textTertiary = Color(light: 0x000000, lightAlpha: 0.38, dark: 0xFFFFFF, darkAlpha: 0.40)
        /// Label color on a `textPrimary` capsule.
        static let onPrimary = Color(light: 0xFFFFFF, dark: 0x07080B)

        /// Volt. Text/glyph use.
        static let accent = Color(light: 0x3B5A00, dark: 0xD4FF3F)
        /// Volt. Fills (progress, rings, hero CTA).
        static let accentFill = Color(light: 0xB8E62A, dark: 0xD4FF3F)
        static let onAccent = Color(light: 0x0B0D12, dark: 0x0B0D12)

        static let fuel = Color(light: 0xE08A00, dark: 0xFFB547)
        static let train = Color(light: 0xE5482A, dark: 0xFF6B4A)
        static let sleep = Color(light: 0x5D5BE0, dark: 0x8E8CFF)
        static let recovery = Color(light: 0x13A877, dark: 0x3EE0A8)

        static let scoreLow = Color(light: 0xE5303F, dark: 0xFF4D5E)
        static let scoreMid = Color(light: 0xE08A00, dark: 0xFFB547)
        static let scoreHigh = recovery

        // Sleep stage tints (DESIGN §5 Hypnogram)
        static let stageAwake = Color(light: 0xE08A00, dark: 0xFFB547)
        static let stageREM = Color(light: 0x8C8AF5, dark: 0xB7B5FF)
        static let stageCore = Color(light: 0x5D5BE0, dark: 0x8E8CFF)
        static let stageDeep = Color(light: 0x34329E, dark: 0x5B58D6)

        static func score(_ value: Int) -> Color {
            switch value {
            case ..<34: scoreLow
            case 34..<67: scoreMid
            default: scoreHigh
            }
        }
    }

    // MARK: Spacing (4-pt grid)
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        static let huge: CGFloat = 48

        static let gutter: CGFloat = 20
        static let section: CGFloat = 32
        static let card: CGFloat = 16
        static let hero: CGFloat = 20
    }

    // MARK: Radius
    enum Radius {
        static let card: CGFloat = 24
        static let inner: CGFloat = 16
        static let small: CGFloat = 12
        static let tiny: CGFloat = 8
        static let sheet: CGFloat = 32
    }

    // MARK: Stroke
    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let trackOpacity: Double = 0.14
    }

    // MARK: Motion
    enum Motion {
        static let standard: Animation = .spring(duration: 0.45, bounce: 0.15)
        static let snappy: Animation = .snappy(duration: 0.25)
        static let fill: Animation = .spring(duration: 1.0, bounce: 0.2)
        static let gentle: Animation = .easeInOut(duration: 0.6)
    }

    // MARK: Layout
    enum Size {
        static let iconButton: CGFloat = 36
        static let directiveIcon: CGFloat = 32
        static let thumbnail: CGFloat = 48
        static let minTap: CGFloat = 44
        static let primaryButtonHeight: CGFloat = 56
    }
}

// MARK: - Typography

enum AtlasTextStyle {
    case display        // serif 34 semibold
    case displayS       // serif 28 semibold
    case serifTitle     // serif 22 medium
    case title          // 22 semibold
    case headline       // 17 semibold
    case body           // 17
    case callout        // 15
    case footnote       // 13
    case micro          // 11 semibold uppercase tracking
    case metricXL       // rounded 60 semibold
    case metricL        // rounded 32 semibold
    case metricM        // rounded 20 semibold
    case metricS        // rounded 15 semibold

    fileprivate var base: (size: CGFloat, weight: Font.Weight, design: Font.Design, relative: Font.TextStyle) {
        switch self {
        case .display: (34, .semibold, .serif, .largeTitle)
        case .displayS: (28, .semibold, .serif, .title)
        case .serifTitle: (22, .medium, .serif, .title2)
        case .title: (22, .semibold, .default, .title2)
        case .headline: (17, .semibold, .default, .headline)
        case .body: (17, .regular, .default, .body)
        case .callout: (15, .regular, .default, .subheadline)
        case .footnote: (13, .regular, .default, .footnote)
        case .micro: (11, .semibold, .default, .caption2)
        case .metricXL: (60, .semibold, .rounded, .largeTitle)
        case .metricL: (32, .semibold, .rounded, .title)
        case .metricM: (20, .semibold, .rounded, .title3)
        case .metricS: (15, .semibold, .rounded, .subheadline)
        }
    }

    var isMetric: Bool {
        switch self {
        case .metricXL, .metricL, .metricM, .metricS: true
        default: false
        }
    }

    /// Dynamic-Type aware font.
    var font: Font {
        let b = base
        return .system(size: b.size, weight: b.weight, design: b.design)
    }
}

private struct AtlasTextStyleModifier: ViewModifier {
    let style: AtlasTextStyle
    @ScaledMetric private var size: CGFloat

    init(style: AtlasTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.base.size, relativeTo: style.base.relative)
    }

    func body(content: Content) -> some View {
        let b = style.base
        // Hero metrics scale, but cap growth so they never blow out a card.
        let scaled = style.isMetric ? min(size, b.size * 1.35) : size
        content
            .font(.system(size: scaled, weight: b.weight, design: b.design))
            .tracking(style == .micro ? 1.2 : 0)
            .textCase(style == .micro ? .uppercase : nil)
            .monospacedDigit()
    }
}

extension View {
    /// Apply an Atlas type style (font, tracking, case, monospaced digits).
    func textStyle(_ style: AtlasTextStyle) -> some View {
        modifier(AtlasTextStyleModifier(style: style))
    }
}

// MARK: - Color helpers

extension Color {
    nonisolated init(light: UInt32, lightAlpha: Double = 1, dark: UInt32, darkAlpha: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Icon sizing
extension Theme {
    enum Icon {
        static let micro: CGFloat = 11
        static let small: CGFloat = 13
        static let regular: CGFloat = 17
        static let large: CGFloat = 22
        static let hero: CGFloat = 34
        static let art: CGFloat = 44
    }
}

extension View {
    /// SF Symbol sizing via Theme.Icon tokens.
    func icon(_ size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        font(.system(size: size, weight: weight))
    }
}
