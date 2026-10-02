import Foundation

nonisolated enum GamePlanEngine {

    /// 3–5 ranked, rule-based directives for today. Facts come from context;
    /// copy follows DESIGN §8 (imperative, numeric, ≤90-char title).
    static func directives(context c: CoachContext) -> [Directive] {
        var out: [Directive] = []
        var cal = Calendar.current
        cal.timeZone = .current
        let units = c.units

        // MARK: Sleep / recovery adjustment
        if let sleep = c.lastSleep {
            let band = ScoreEngine.scoreBand(sleep.score)
            if band == .low || (c.recoveryScore ?? 100) < 40 {
                let sessionName = c.todaySession?.title
                let swap = sessionName != nil
                    ? "Swap \(sessionName!) for mobility + 20 min Zone 2"
                    : "Keep today easy — mobility + 20 min Zone 2"
                var detail = "Sleep was \(Fmt.duration(minutes: sleep.asleepMin)) (score \(sleep.score))"
                if let d = c.hrvDeltaPct {
                    detail += ", HRV \(String(format: "%+.0f", d))% vs baseline"
                }
                detail += ". Go light, caffeine cutoff 2 PM, lights out by \(Fmt.clock(c.recommendedBedtime))."
                out.append(Directive(
                    title: swap, detail: detail, pillar: .recovery, priority: 10,
                    action: CoachAction(kind: .setReminder,
                                        title: "Wind-down reminder",
                                        subtitle: "45 min before \(Fmt.clock(c.recommendedBedtime))",
                                        params: ["title": "Wind down — screens off",
                                                 "body": "Lights out by \(Fmt.clock(c.recommendedBedtime)) for \(Fmt.duration(minutes: c.sleepNeedMin)) of sleep.",
                                                 "fireISO": iso(c.recommendedBedtime.addingTimeInterval(-45 * 60))])
                ))
            } else if let r = c.recoveryScore, r >= 67, c.todaySession != nil {
                out.append(Directive(
                    title: "Recovered \(r) — full send on \(c.todaySession!.title)",
                    detail: "Sleep \(Fmt.duration(minutes: sleep.asleepMin)), score \(sleep.score). Hit the session as written today.",
                    pillar: .recovery, priority: 6, action: nil))
            }
        }

        // MARK: Calendar events (dinner/lunch/drinks/flight/restaurant)
        let foodKeywords = ["dinner", "lunch", "drinks", "brunch", "restaurant", "reservation", "bbq", "meal"]
        for ev in c.events {
            let lower = ev.title.lowercased()
            let isMealish = foodKeywords.contains { lower.contains($0) } || lower.contains("@")
            let isFlight = lower.contains("flight") || lower.contains("fly ")
            if isFlight {
                out.append(Directive(
                    title: "Travel today — front-load protein before \(Fmt.clock(ev.start))",
                    detail: "Flights wreck routines. Hit \(c.targets.proteinG / 2)+ g protein before you leave and walk the terminal.",
                    pillar: .fuel, priority: 7, action: nil))
            } else if isMealish {
                let time = Fmt.clock(ev.start)
                let name = ev.location ?? ev.title
                let restaurant = ev.location?.components(separatedBy: ",").first ?? ev.title
                // Lunch budget: ~35% of remaining kcal, high protein.
                // Cap at what's left minus a ~600 dinner reserve; never negative.
                let lunchKcal = max(0, min(Int((c.remaining.kcal * 0.35 / 10).rounded() * 10),
                                           Int(c.remaining.kcal) - 600))
                let lunchProtein = max(40, c.targets.proteinG / 3)
                var detail = "Keep lunch ~\(Fmt.kcal(Double(lunchKcal))) kcal, \(lunchProtein) g protein"
                if let w = c.eatingWindow {
                    detail += w.isOpen ? "; \(name) fits your window" : "; note \(name) lands outside your usual window"
                }
                detail += "."
                let hasReservation = lower.contains("reservation") || lower.contains("booked")
                var action: CoachAction? = CoachAction(
                    kind: .orderMeal,
                    title: "Lunch that fits",
                    subtitle: "~\(Fmt.kcal(Double(lunchKcal))) kcal · \(lunchProtein) g protein",
                    params: ["query": "high protein bowl", "provider": "doordash",
                             "suggestion": "Double-protein bowl, rice light\nSide of edamame\nWater or diet soda",
                             "kcal": "\(lunchKcal)", "protein": "\(lunchProtein)"])
                if !hasReservation {
                    let dinnerish = lower.contains("dinner") || lower.contains("drinks") || cal.component(.hour, from: ev.start) >= 17
                    if dinnerish {
                        action = CoachAction(
                            kind: .reserveTable,
                            title: "Reserve \(restaurant)",
                            subtitle: "Tonight · \(time)" + orderGuide(for: restaurant),
                            params: ["restaurant": restaurant, "partySize": "2",
                                     "dateISO": iso(ev.start),
                                     "orderGuide": orderGuideBody(for: restaurant)])
                    }
                }
                out.append(Directive(
                    title: "\(ev.title) at \(time) — keep lunch ~\(Fmt.kcal(Double(lunchKcal))) kcal",
                    detail: detail, pillar: .fuel, priority: 8, action: action))
            }
        }

        // MARK: Eating window state
        if let w = c.eatingWindow {
            if !w.isOpen && cal.isDateInToday(w.opens) && w.opens > c.now {
                out.append(Directive(
                    title: "Window opens at \(Fmt.clock(w.opens)) — first meal 40 g+ protein",
                    detail: "Break the fast with protein first: it steadies appetite for the rest of the window.",
                    pillar: .fuel, priority: 7, action: nil))
            } else if w.isOpen {
                let toGoP = Int(max(0, c.remaining.protein))
                if w.minutesToNextChange <= 150 {
                    out.append(Directive(
                        title: "Window closes in \(Fmt.duration(minutes: w.minutesToNextChange)) — \(toGoP) g protein to go",
                        detail: "Front-load it now: you still need \(Fmt.kcal(max(0, c.remaining.kcal))) kcal and \(toGoP) g protein before \(Fmt.clock(w.closes)).",
                        pillar: .fuel, priority: 9,
                        action: CoachAction(kind: .orderMeal, title: "Order something that fits",
                                            subtitle: "\(toGoP) g protein to go",
                                            params: ["query": "high protein", "provider": "doordash",
                                                     "kcal": "\(Int(c.remaining.kcal))", "protein": "\(toGoP)"])))
                } else if toGoP > c.targets.proteinG * 2 / 3 && c.remaining.kcal > 0 {
                    out.append(Directive(
                        title: "\(toGoP) g protein still to go — plan the rest of the window",
                        detail: "You've eaten \(Fmt.kcal(c.eaten.kcal)) of \(Fmt.kcal(Double(c.targets.kcal))) kcal. Don't save it all for dinner.",
                        pillar: .fuel, priority: 6, action: nil))
                }
            } else {
                out.append(Directive(
                    title: "Kitchen's closed. Next window \(Fmt.clock(w.nextChange))",
                    detail: "Done for today: \(Fmt.kcal(c.eaten.kcal)) kcal, \(Int(c.eaten.protein)) g protein. Water and herbal tea only until \(Fmt.clock(w.nextChange)).",
                    pillar: .fuel, priority: 5, action: nil))
            }
        }

        // MARK: Protein pace (when no window logic fired)
        if c.eatingWindow == nil, c.remaining.protein > 30, c.remaining.kcal > 0 {
            out.append(Directive(
                title: "\(Int(c.remaining.protein)) g protein left — spread it over your next two meals",
                detail: "You're at \(Int(c.eaten.protein)) of \(c.targets.proteinG) g. Aim for \(Int(c.remaining.protein / 2)) g per meal.",
                pillar: .fuel, priority: 5, action: nil))
        }

        // MARK: Today's session / rest day
        let sleepLow = (c.lastSleep?.score ?? 100) < 40
        if let s = c.todaySession, !sleepLow, c.completedToday.isEmpty {
            let blockNames = s.blocks.map(\.title).joined(separator: " · ")
            out.append(Directive(
                title: "\(s.title): \(blockNames)",
                detail: "\(s.durationMin) min, \(s.focus). \(firstCue(of: s))",
                pillar: .train, priority: 7,
                action: CoachAction(kind: .scheduleWorkout, title: "Schedule \(s.title)",
                                    subtitle: "\(s.durationMin) min",
                                    params: ["title": "Atlas: \(s.title)",
                                             "durationMin": "\(s.durationMin)",
                                             "notes": s.blocks.map { "\($0.title): \($0.exercises.map(\.name).joined(separator: ", "))" }.joined(separator: "\n")])))
        } else if c.todaySession == nil && c.completedToday.isEmpty {
            out.append(Directive(
                title: "Rest day — walk 8k steps" + (c.steps.map { " (\(Fmt.kcal(Double($0))) so far)" } ?? ""),
                detail: "Recovery is the program today. Keep steps up" + (c.load.status == "High" ? "; your weekly load is running hot." : "."),
                pillar: .train, priority: 4, action: nil))
        }

        // MARK: Goal projection nudge
        if let g = c.goal {
            let valStr = Fmt.metric(g.current, metric: g.metric, units: units, customUnit: g.customUnit)
            let tgtStr = Fmt.metric(g.target, metric: g.metric, units: units, customUnit: g.customUnit)
            switch g.projection.status {
            case .behind:
                out.append(Directive(
                    title: "You're behind pace — \(valStr) of \(tgtStr), \(g.daysLeft) days left",
                    detail: "Tighten the inputs this week: hit protein every day and don't miss sessions. Log a check-in measurement today.",
                    pillar: .goal, priority: 8,
                    action: nil))
            case .ahead:
                out.append(Directive(
                    title: "\(g.projection.daysVsTarget) days ahead — \(valStr) of \(tgtStr)",
                    detail: "Stay the course. Next milestone lands about \(Fmt.date(g.projection.projectedDate ?? c.now)).",
                    pillar: .goal, priority: 3, action: nil))
            case .onTrack:
                break // covered enough by others
            case .insufficientData:
                out.append(Directive(
                    title: "Log a \(g.metric.title.lowercased()) check-in — last was \(valStr)",
                    detail: "Two or more data points let me project your date to \(tgtStr).",
                    pillar: .goal, priority: 6, action: nil))
            case .reached:
                out.append(Directive(
                    title: "Goal hit — \(valStr). Time to set the next one",
                    detail: "Bank the win, then let's pick what's next.",
                    pillar: .goal, priority: 9, action: nil))
            }
        }

        // MARK: Ensure at least 3 — goal check-in fallback
        if out.count < 3, let g = c.goal {
            let valStr = Fmt.metric(g.current, metric: g.metric, units: units, customUnit: g.customUnit)
            out.append(Directive(
                title: "Check in — log a \(g.metric.title.lowercased()) measurement",
                detail: "Last reading \(valStr). Fresh data keeps your projection to \(Fmt.metric(g.target, metric: g.metric, units: units, customUnit: g.customUnit)) honest.",
                pillar: .goal, priority: 2, action: nil))
        }

        // MARK: Bedtime (when actionable and nothing bigger)
        if out.count < 5, let sleep = c.lastSleep, sleep.score < 70 {
            out.append(Directive(
                title: "Lights out by \(Fmt.clock(c.recommendedBedtime)) — \(Fmt.duration(minutes: c.sleepNeedMin)) tonight",
                detail: "You need \(Fmt.duration(minutes: c.sleepNeedMin)) after last night. Wind down 45 min early.",
                pillar: .sleep, priority: 5,
                action: CoachAction(kind: .setReminder, title: "Wind-down reminder",
                                    subtitle: Fmt.clock(c.recommendedBedtime.addingTimeInterval(-45 * 60)),
                                    params: ["title": "Wind down",
                                             "body": "Lights out by \(Fmt.clock(c.recommendedBedtime)).",
                                             "fireISO": iso(c.recommendedBedtime.addingTimeInterval(-45 * 60))])))
        }

        return Array(out.sorted { $0.priority > $1.priority }.prefix(5))
    }

    // MARK: - Helpers

    private static func firstCue(of s: PlannedSession) -> String {
        s.blocks.first?.exercises.first?.cue ?? "Warm up 5 minutes first."
    }

    private static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: d)
    }

    /// Short order-guide blurb for a restaurant name.
    private static func orderGuide(for restaurant: String) -> String {
        let r = restaurant.lowercased()
        if r.contains("nobu") || r.contains("sushi") {
            return " · order guide ready"
        }
        return ""
    }

    static func orderGuideBody(for restaurant: String) -> String {
        let r = restaurant.lowercased()
        if r.contains("nobu") || r.contains("sushi") {
            return "Black cod miso (half portion)\nSashimi plate\nEdamame\nSkip: tempura, sweet sauces"
        }
        if r.contains("steak") {
            return "Lean cut, no butter finish\nSalad or veg sides\nSkip: loaded potatoes, creamed sides"
        }
        if r.contains("mexican") || r.contains("chipotle") {
            return "Bowl, not burrito\nDouble protein, rice light\nSkip: queso, sour cream, chips"
        }
        return "Lean protein entrée\nVegetable sides\nSkip: fried starters, sugary drinks"
    }
}
