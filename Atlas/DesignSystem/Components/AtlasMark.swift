import SwiftUI

/// The Atlas mark: a globe resting on the titan's shoulders (DESIGN §1).
/// Proportions match scripts/render-icon.swift (unit square).
struct AtlasMarkShape: Shape {
    var part: Part = .both
    enum Part { case globe, shoulders, both }

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let ox = rect.midX - s / 2
        let oy = rect.midY - s / 2
        var path = Path()
        if part != .shoulders {
            let r = 0.1465 * s
            let c = CGPoint(x: ox + 0.5 * s, y: oy + 0.371 * s)
            path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        if part != .globe {
            let center = CGPoint(x: ox + 0.5 * s, y: oy + 1.035 * s)
            let radius = 0.459 * s
            var arc = Path()
            // ends near x = 0.227 / 0.773
            let half = asin((0.5 - 0.227) / 0.459)
            arc.addArc(center: center, radius: radius,
                       startAngle: .radians(-.pi / 2 - half), endAngle: .radians(-.pi / 2 + half), clockwise: false)
            path.addPath(arc.strokedPath(StrokeStyle(lineWidth: 0.0625 * s, lineCap: .round)))
        }
        return path
    }
}

struct AtlasMark: View {
    var size: CGFloat = 40
    var color: Color = Theme.Palette.textPrimary
    var glow = false

    var body: some View {
        ZStack {
            if glow {
                AtlasMarkShape(part: .globe)
                    .fill(Theme.Palette.accentFill.opacity(0.35))
                    .blur(radius: size * 0.08)
            }
            AtlasMarkShape().fill(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Small avatar used beside coach messages.
struct CoachAvatar: View {
    var size: CGFloat = 28
    var body: some View {
        AtlasMark(size: size * 0.78, color: Theme.Palette.textPrimary)
            .frame(width: size, height: size)
            .background(Theme.Palette.fill, in: .circle)
    }
}
