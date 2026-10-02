import Foundation

/// Raw inputs for one night of sleep.
struct SleepInput: Sendable {
    var start: Date
    var end: Date
    var stages: [SleepStageSegment]
    var hrvMs: Double?
    var restingHR: Double?
    var quality: Int?          // 1–5 (manual entries)
}

enum ScoreEngine {

    // MARK: - Sleep

    static func sleepSummary(_ input: SleepInput) -> SleepSummary {
        let inBedMin = Int(input.end.timeIntervalSince(input.start) / 60)
        var awake = 0, rem = 0, core = 0, deep = 0
        for s in input.stages {
            switch s.stage {
            case .awake: awake += Int(s.minutes)
            case .rem: rem += Int(s.minutes)
            case .core: core += Int(s.minutes)
            case .deep: deep += Int(s.minutes)
            }
        }
        var asleep = rem + core + deep
        if input.stages.isEmpty {
            // No stage detail (manual log): estimate awake share from quality.
            let awakeFrac: Double
            switch input.quality ?? 3 {
            case 1: awakeFrac = 0.22
            case 2: awakeFrac = 0.15
            case 3: awakeFrac = 0.10
            case 4: awakeFrac = 0.07
            default: awakeFrac = 0.05
            }
            awake = Int(Double(inBedMin) * awakeFrac)
            asleep = inBedMin - awake
        }
        let efficiency = inBedMin > 0 ? Double(asleep) / Double(inBedMin) : 0
        return SleepSummary(start: input.start, end: input.end,
                            asleepMin: asleep, inBedMin: inBedMin,
                            efficiency: efficiency,
                            awakeMin: awake, remMin: rem, coreMin: core, deepMin: deep,
                            hrvMs: input.hrvMs, restingHR: input.restingHR, score: 0)
    }

    /// 0–100. 50% duration vs need, 20% efficiency, 15% deep+REM share,
    /// 15% bedtime consistency (SD of recent bedtimes, lower is better).
    static func sleepScore(summary: SleepSummary, needMin: Int, recentBedtimes: [Date] = []) -> Int {
        let durationScore = min(1.0, Double(summary.asleepMin) / Double(max(1, needMin)))
        let efficiencyScore = min(1.0, max(0, (summary.efficiency - 0.6) / 0.35)) // 60%→0, 95%→1
        let restorative = summary.asleepMin > 0
            ? Double(summary.remMin + summary.deepMin) / Double(summary.asleepMin)
            : 0
        let restorativeScore = min(1.0, restorative / 0.40) // 40% deep+REM → full

        var consistencyScore = 0.75 // neutral default
        if recentBedtimes.count >= 3 {
            var cal = Calendar.current
            cal.timeZone = .current
            let minutes = recentBedtimes.map { d -> Double in
                var m = Double(cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d))
                if m > 18 * 60 { m -= 24 * 60 } // wrap past midnight
                return m
            }
            let mean = minutes.reduce(0, +) / Double(minutes.count)
            let sd = sqrt(minutes.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(minutes.count))
            consistencyScore = min(1.0, max(0, 1.0 - sd / 60.0)) // 60 min SD → 0
        }

        let score = 100 * (0.50 * durationScore + 0.20 * efficiencyScore
                           + 0.15 * restorativeScore + 0.15 * consistencyScore)
        return max(0, min(100, Int(score.rounded())))
    }

    /// 0–100. 40% sleep, 35% HRV vs baseline, 25% RHR vs baseline.
    /// Falls back to sleep-only when HRV/RHR baselines are missing.
    static func recoveryScore(sleepScore: Int, hrv: Double?, hrvBaseline: Double?,
                              rhr: Double?, rhrBaseline: Double?) -> Int {
        var parts: [(weight: Double, value: Double)] = [(0.40, Double(sleepScore))]
        var weightSum = 0.40

        if let hrv, let hrvBaseline, hrvBaseline > 0 {
            let delta = (hrv - hrvBaseline) / hrvBaseline // ±
            // ±25% delta maps to ∓100..0 around 100 at 0.
            let hrvScore = max(0, min(100, 50 + delta * 200))
            parts.append((0.35, hrvScore))
            weightSum += 0.35
        }
        if let rhr, let rhrBaseline, rhrBaseline > 0 {
            let delta = (rhr - rhrBaseline) / rhrBaseline // up is worse
            let rhrScore = max(0, min(100, 50 - delta * 400)) // +12.5% → 0
            parts.append((0.25, rhrScore))
            weightSum += 0.25
        }
        let score = parts.reduce(0) { $0 + $1.weight * $1.value } / weightSum
        return max(0, min(100, Int(score.rounded())))
    }

    /// Tonight's sleep need: base + load-driven extra + debt repayment.
    static func sleepNeed(baseMin: Int = 480, acuteLoad: Double = 0,
                          chronicLoad: Double = 0, debtMin: Int = 0) -> Int {
        var need = Double(baseMin)
        if chronicLoad > 0 {
            let ratio = acuteLoad / chronicLoad
            if ratio > 1.3 { need += 30 }
            else if ratio > 1.1 { need += 15 }
        } else if acuteLoad > 400 {
            need += 15
        }
        need += Double(debtMin) * 0.5
        return min(Int(need.rounded()), 600)
    }

    // MARK: - Training load

    /// sRPE: duration (min) × RPE.
    static func sessionLoad(durationMin: Int, rpe: Double) -> Double {
        Double(durationMin) * rpe
    }

    /// Acute (7d) vs chronic (28d weekly avg) load ratio.
    static func trainingLoad(workouts: [(date: Date, load: Double)], now: Date,
                             calendar: Calendar = .current) -> TrainingLoad {
        let day: TimeInterval = 86400
        var acute = 0.0, chronicTotal = 0.0
        for w in workouts {
            let age = now.timeIntervalSince(w.date)
            if age <= 7 * day { acute += w.load }
            if age <= 28 * day { chronicTotal += w.load }
        }
        let chronic = chronicTotal / 4
        let ratio = chronic > 0 ? acute / chronic : (acute > 0 ? 2.0 : 0)
        let status: String
        if chronic == 0 && acute == 0 { status = "Low" }
        else if ratio > 1.4 { status = "High" }
        else if ratio < 0.6 { status = "Low" }
        else { status = "Optimal" }
        return TrainingLoad(acute7: acute, chronic28: chronic, ratio: ratio, status: status)
    }

    /// Wake = first event − 75 min (default 7:00 AM); bed = wake − need − 15 min.
    static func recommendedBedtime(firstEventTomorrow: CalendarEventInfo?, needMin: Int,
                                   now: Date, calendar: Calendar = .current) -> Date {
        var wake: Date
        if let ev = firstEventTomorrow {
            wake = ev.start.addingTimeInterval(-75 * 60)
        } else {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            comps.hour = 7
            comps.minute = 0
            wake = calendar.date(from: comps)!
        }
        return wake.addingTimeInterval(-Double(needMin) * 60 - 15 * 60)
    }

    static func scoreBand(_ score: Int) -> ScoreBand {
        if score < 34 { return .low }
        if score < 67 { return .mid }
        return .high
    }
}
