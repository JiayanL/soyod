import SwiftUI

/// Stepped sleep-stage chart (Awake / REM / Core / Deep).
struct Hypnogram: View {
    struct Segment: Identifiable, Hashable {
        let id: Int
        /// 0 = awake, 1 = REM, 2 = core, 3 = deep
        let level: Int
        let start: Date
        let end: Date
    }

    let segments: [Segment]
    var height: CGFloat = 140

    static let levels: [(String, Color)] = [
        ("Awake", Theme.Palette.stageAwake),
        ("REM", Theme.Palette.stageREM),
        ("Core", Theme.Palette.stageCore),
        ("Deep", Theme.Palette.stageDeep)
    ]

    var body: some View {
        let start = segments.map(\.start).min() ?? .now
        let end = segments.map(\.end).max() ?? .now
        let span = max(1, end.timeIntervalSince(start))
        HStack(alignment: .top, spacing: Theme.Space.s) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Self.levels.enumerated()), id: \.offset) { _, level in
                    Text(level.0)
                        .textStyle(.micro)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(height: height / 4, alignment: .center)
                }
            }
            .fixedSize()
            VStack(spacing: Theme.Space.xs) {
                Canvas { ctx, size in
                    let rowH = size.height / 4
                    // grid
                    for i in 0..<4 {
                        let y = rowH * (CGFloat(i) + 0.5)
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y))
                        line.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(line, with: .color(Theme.Palette.hairline), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    }
                    // connectors
                    var connector = Path()
                    for (i, seg) in segments.enumerated() {
                        let x = CGFloat(seg.start.timeIntervalSince(start) / span) * size.width
                        let y = rowH * (CGFloat(seg.level) + 0.5)
                        if i == 0 { connector.move(to: CGPoint(x: x, y: y)) } else { connector.addLine(to: CGPoint(x: x, y: y)) }
                        let x2 = CGFloat(seg.end.timeIntervalSince(start) / span) * size.width
                        connector.addLine(to: CGPoint(x: x2, y: y))
                    }
                    ctx.stroke(connector, with: .color(Theme.Palette.textTertiary.opacity(0.6)), lineWidth: 1)
                    // bars
                    for seg in segments {
                        let x = CGFloat(seg.start.timeIntervalSince(start) / span) * size.width
                        let w = max(2, CGFloat(seg.end.timeIntervalSince(seg.start) / span) * size.width)
                        let y = rowH * CGFloat(seg.level) + rowH * 0.2
                        let rect = CGRect(x: x, y: y, width: w, height: rowH * 0.6)
                        let color = Self.levels[min(3, max(0, seg.level))].1
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))
                    }
                }
                .frame(height: height)
                HStack {
                    Text(start, format: .dateTime.hour().minute())
                    Spacer()
                    Text(end, format: .dateTime.hour().minute())
                }
                .textStyle(.micro)
                .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stages chart")
    }
}
