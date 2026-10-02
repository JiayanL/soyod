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
                    let barH = rowH * 0.62
                    func x(_ d: Date) -> CGFloat { CGFloat(d.timeIntervalSince(start) / span) * size.width }
                    func y(_ level: Int) -> CGFloat { rowH * (CGFloat(min(3, max(0, level))) + 0.5) }
                    func color(_ level: Int) -> Color { Self.levels[min(3, max(0, level))].1 }
                    for i in 0..<4 {
                        var line = Path()
                        line.move(to: CGPoint(x: 0, y: y(i)))
                        line.addLine(to: CGPoint(x: size.width, y: y(i)))
                        ctx.stroke(line, with: .color(Theme.Palette.hairline), lineWidth: 0.5)
                    }
                    let merged = Self.merge(segments)
                    for (a, b) in zip(merged, merged.dropFirst()) where a.level != b.level {
                        var link = Path()
                        let cx = x(b.start)
                        link.move(to: CGPoint(x: cx, y: y(a.level)))
                        link.addLine(to: CGPoint(x: cx, y: y(b.level)))
                        ctx.stroke(link,
                                   with: .linearGradient(Gradient(colors: [color(a.level), color(b.level)]),
                                                         startPoint: CGPoint(x: cx, y: y(a.level)),
                                                         endPoint: CGPoint(x: cx, y: y(b.level))),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                    for seg in merged {
                        let w = max(barH * 0.5, x(seg.end) - x(seg.start))
                        let rect = CGRect(x: x(seg.start), y: y(seg.level) - barH / 2, width: w, height: barH)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: min(barH, w) / 2), with: .color(color(seg.level)))
                    }
                }
                .frame(height: height)
                GeometryReader { geo in
                    ForEach(Self.hourTicks(from: start, to: end), id: \.self) { tick in
                        Text(tick, format: .dateTime.hour())
                            .textStyle(.micro)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .fixedSize()
                            .position(x: CGFloat(tick.timeIntervalSince(start) / span) * geo.size.width,
                                      y: geo.size.height / 2)
                    }
                }
                .frame(height: Theme.Space.m)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stages chart")
    }

    /// Joins back-to-back segments of the same stage so the chart reads as one continuous line.
    static func merge(_ segments: [Segment]) -> [Segment] {
        var out: [Segment] = []
        for seg in segments.sorted(by: { $0.start < $1.start }) {
            if let last = out.last, last.level == seg.level {
                out[out.count - 1] = Segment(id: last.id, level: last.level, start: last.start, end: max(last.end, seg.end))
            } else {
                out.append(seg)
            }
        }
        return out
    }

    /// Whole hours inside the night, thinned to every second hour for long nights.
    static func hourTicks(from start: Date, to end: Date, calendar: Calendar = .current) -> [Date] {
        guard var t = calendar.nextDate(after: start, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) else { return [] }
        var ticks: [Date] = []
        while t < end.addingTimeInterval(-20 * 60) {
            if t.timeIntervalSince(start) > 20 * 60 { ticks.append(t) }
            t = t.addingTimeInterval(3600)
        }
        return ticks.count > 6 ? ticks.enumerated().filter { $0.offset % 2 == 0 }.map(\.element) : ticks
    }
}
