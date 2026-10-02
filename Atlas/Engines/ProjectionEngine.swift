import Foundation

enum ProjectionEngine {

    /// Linear regression over measurements → projection to target.
    /// Values are canonical; `isDecreasing` is inferred from target < baseline.
    static func project(baseline: Double, start: Date,
                        measurements: [(date: Date, value: Double)],
                        target: Double, targetDate: Date, now: Date) -> Projection {
        let decreasing = target < baseline
        let current = measurements.last?.value ?? baseline
        let span = abs(target - baseline)
        let progress: Double
        if span == 0 {
            progress = decreasing ? (current <= target ? 1 : 0) : (current >= target ? 1 : 0)
        } else {
            progress = min(1.2, max(0, abs(current - baseline) / span))
        }

        // Already reached?
        let reached = decreasing ? current <= target : current >= target
        if reached {
            return Projection(current: current, slopePerDay: 0, projectedDate: nil,
                              status: .reached, daysVsTarget: 0, progress: 1)
        }

        // Need ≥2 points spread over ≥5 days for a slope.
        guard measurements.count >= 2,
              let first = measurements.first, let last = measurements.last,
              last.date.timeIntervalSince(first.date) >= 5 * 86400 else {
            return Projection(current: current, slopePerDay: 0, projectedDate: nil,
                              status: .insufficientData, daysVsTarget: 0, progress: progress)
        }

        // OLS: x = days since start, y = value.
        let xs = measurements.map { $0.date.timeIntervalSince(start) / 86400 }
        let ys = measurements.map(\.value)
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0
        for i in 0..<xs.count {
            sxy += (xs[i] - mx) * (ys[i] - my)
            sxx += (xs[i] - mx) * (xs[i] - mx)
        }
        let slope = sxx > 0 ? sxy / sxx : 0

        // Moving the wrong way?
        let improving = decreasing ? slope < 0 : slope > 0
        guard improving, abs(slope) > 1e-9 else {
            return Projection(current: current, slopePerDay: slope, projectedDate: nil,
                              status: .behind, daysVsTarget: Int(targetDate.timeIntervalSince(now) / 86400) * -1,
                              progress: progress)
        }

        let remaining = abs(target - current)
        let daysToTarget = remaining / abs(slope)
        let projected = now.addingTimeInterval(daysToTarget * 86400)
        let daysVsTarget = Int(targetDate.timeIntervalSince(projected) / 86400) // + = early
        let status: ProjectionStatus
        if daysVsTarget > 7 { status = .ahead }
        else if daysVsTarget < -14 { status = .behind }
        else { status = .onTrack }

        return Projection(current: current, slopePerDay: slope, projectedDate: projected,
                          status: status, daysVsTarget: daysVsTarget, progress: progress)
    }

    /// Checkpoints every ~4 weeks, linear from baseline to target.
    static func milestones(goal: GoalSnapshot, measurements: [(date: Date, value: Double)],
                           now: Date, units: UnitSystem = .imperial) -> [Milestone] {
        let totalDays = goal.targetDate.timeIntervalSince(goal.startDate) / 86400
        guard totalDays > 7 else { return [] }
        let count = max(2, Int(totalDays / 28))
        var result: [Milestone] = []
        for i in 1...count {
            let frac = Double(i) / Double(count + 1)
            let date = goal.startDate.addingTimeInterval(frac * totalDays * 86400)
            let value = goal.baseline + (goal.target - goal.baseline) * frac
            let wk = Int((frac * totalDays) / 7)
            let valStr = Fmt.metric(value, metric: goal.metric, units: units, customUnit: goal.customUnit)
            let title = "Week \(wk) check-in: \(valStr)"
            let reached = measurements.contains { m in
                m.date <= date && (goal.target < goal.baseline ? m.value <= value : m.value >= value)
            }
            result.append(Milestone(date: date, value: value, title: title, isReached: reached))
        }
        return result
    }
}
