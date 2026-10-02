import Foundation

/// Always-available on-device coach. Intent classifier + responses composed
/// from CoachContext facts — real numbers, times, and memories, tone-aware.
final class RuleBasedCoach: CoachAgent {
    let displayName = "Atlas on-device"

    func respond(to text: String, history: [ChatTurn], context c: CoachContext) async throws -> CoachReply {
        let lower = text.lowercased()
        var reply = CoachReply(text: "")

        // Always harvest explicit memories ("remember that…", "my knee…").
        reply.memoryWrites = MemoryExtractor.extract(from: text, now: c.now)

        // MARK: logMeal — "I ate / had 2 eggs and toast"
        if isLogMeal(lower) {
            let items = FoodTextParser.parse(text)
            if !items.isEmpty {
                let total = items.reduce(MacroTotals()) {
                    $0 + MacroTotals(kcal: $1.kcal, protein: $1.protein, carbs: $1.carbs, fat: $1.fat)
                }
                let after = MacroTotals(kcal: c.remaining.kcal - total.kcal,
                                        protein: c.remaining.protein - total.protein,
                                        carbs: c.remaining.carbs - total.carbs,
                                        fat: c.remaining.fat - total.fat)
                let title = items.map(\.name).joined(separator: ", ")
                let mealType = AppState.defaultMealType(at: c.now)
                reply.logs.append(.meal(title: title, mealType: mealType, items: items))
                reply.text = tone(c.tone,
                    direct: "Logged \(title): \(Fmt.kcal(total.kcal)) kcal, \(Int(total.protein)) g protein. You're at \(Fmt.kcal(max(0, after.kcal))) kcal and \(Int(max(0, after.protein))) g protein left.",
                    encouraging: "Nice — logged \(title) at \(Fmt.kcal(total.kcal)) kcal and \(Int(total.protein)) g protein. \(Int(max(0, after.protein))) g protein to go, you're doing great.",
                    nerd: "Logged: \(items.map { "\($0.name) ×\(trimmed($0.quantity))" }.joined(separator: ", ")) = \(Fmt.kcal(total.kcal)) kcal (\(Int(total.protein))P/\(Int(total.carbs))C/\(Int(total.fat))F). Remaining: \(Fmt.kcal(max(0, after.kcal))) kcal, \(Int(max(0, after.protein))) g protein.")
                return reply
            }
            reply.text = "I couldn't match that to foods I know — try \"2 eggs, 1 cup rice\" or use Search."
            return reply
        }

        // MARK: logWorkout — "I ran 5k in 26 min", "played basketball 90 min", "did legs"
        if let w = parseWorkout(lower, context: c) {
            reply.logs.append(w.log)
            var extras = "That's \(Int(w.load)) load points"
            if w.kind == .cardio, let pace = w.pace {
                extras += " at \(pace)"
            }
            reply.text = tone(c.tone,
                direct: "Logged \(w.title), \(w.durationMin) min. \(extras).",
                encouraging: "Logged — nice work. \(w.title), \(w.durationMin) min. \(extras).",
                nerd: "Logged \(w.title): \(w.durationMin) min, sRPE load \(Int(w.load))\(w.pace.map { ", pace \($0)" } ?? "").")
            return reply
        }

        // MARK: bad sleep
        if containsAny(lower, ["slept badly", "slept bad", "bad sleep", "tired", "exhausted", "bad night", "didn't sleep", "couldn't sleep", "rough night"]) {
            return badSleepReply(context: c, memories: reply.memoryWrites)
        }

        // MARK: dinner / restaurant
        if let restaurant = detectRestaurant(lower, context: c) {
            return dinnerReply(restaurant: restaurant, text: text, context: c, memories: reply.memoryWrites)
        }

        // MARK: order food / hungry
        if containsAny(lower, ["order me", "order lunch", "order food", "hungry", "what should i eat", "what to eat", "get me food"]) {
            return orderReply(context: c, memories: reply.memoryWrites)
        }

        // MARK: reschedule / skip
        if containsAny(lower, ["can't train", "cant train", "skip workout", "move workout", "reschedule", "no time to train", "miss my workout"]) {
            return rescheduleReply(context: c, memories: reply.memoryWrites)
        }

        // MARK: plan explanation
        if containsAny(lower, ["why", "explain my plan", "why am i doing", "explain", "what's the plan"]) {
            reply.text = planExplanation(context: c)
            return reply
        }

        // MARK: on track / status
        if containsAny(lower, ["on track", "am i on", "how am i doing", "progress", "status"]) {
            reply.text = statusReply(context: c)
            return reply
        }

        // MARK: motivation
        if containsAny(lower, ["motivate", "give up", "don't want to", "unmotivated", "can't do this", "why bother"]) {
            reply.text = tone(c.tone,
                direct: "Motivation is overrated — you have a system. Do today's session, hit your protein, sleep \(Fmt.duration(minutes: c.sleepNeedMin)). That's the whole job.",
                encouraging: "You've already put in real work — don't stop now. One session, one good meal, one good night. Start with whichever's easiest.",
                nerd: "Adherence beats intensity: your last 14 days show \(c.recentWorkouts.count) sessions. Consistency compounds — today's small win is worth more than a heroic weekend.")
            return reply
        }

        // MARK: travel
        if containsAny(lower, ["travel", "flight", "airport", "hotel", "trip"]) {
            reply.text = "Travel plan: protein first at every meal (airport food is carb-heavy), a 20-min hotel room session beats nothing, and protect the sleep window. Want me to write that into a reminder?"
            reply.actions.append(CoachAction(kind: .setReminder, title: "Travel-day reminder",
                                             subtitle: "Protein first + 20 min room workout",
                                             params: ["title": "Travel day rules",
                                                      "body": "Protein first, 20-min room session, protect bedtime.",
                                                      "fireISO": iso(c.now.addingTimeInterval(3600))]))
            return reply
        }

        // MARK: pain / injury
        if containsAny(lower, ["knee", "hurt", "pain", "injur", "sore"]) {
            var t = "Noted — I've saved that. "
            if let knee = c.memories.first(where: { $0.text.lowercased().contains("knee") }) {
                t += "You already have \"\(knee.text)\" on file, so I'll keep impact work conservative. "
            }
            t += "Swap jumps/runs for bike or upper-body work until it calms down. Sharp or worsening pain → see a physio, not a coach."
            reply.text = t
            if reply.memoryWrites.isEmpty {
                reply.memoryWrites.append(MemoryDraft(kind: .fact, text: text.prefix(1).uppercased() + text.dropFirst(), dueDate: nil))
            }
            return reply
        }

        // MARK: fallback — summarize today with numbers
        reply.text = fallbackSummary(context: c)
        return reply
    }

    // MARK: - Intents

    private func isLogMeal(_ lower: String) -> Bool {
        (lower.hasPrefix("i ate") || lower.hasPrefix("i had") || lower.hasPrefix("just ate")
         || lower.hasPrefix("ate ") || lower.hasPrefix("had ") || lower.contains("for breakfast")
         || lower.contains("for lunch") || lower.contains("for dinner"))
        && !lower.contains("should i")
    }

    private func containsAny(_ s: String, _ keys: [String]) -> Bool {
        keys.contains { s.contains($0) }
    }

    private struct ParsedWorkout {
        var log: CoachLog
        var title: String
        var kind: WorkoutKind
        var durationMin: Int
        var load: Double
        var pace: String?
    }

    private func parseWorkout(_ lower: String, context c: CoachContext) -> ParsedWorkout? {
        // "ran 5k in 26 min" / "ran 5 miles in 40 min" / "played basketball for 90 min" / "did legs"
        let runMatch = lower.range(of: #"ran|run|jog"#, options: .regularExpression) != nil
        let distM = lower.range(of: #"(\d+(?:\.\d+)?)\s*(k|km|kilometers?|miles?|mi)"#, options: .regularExpression)
        let durM = lower.range(of: #"(\d+)\s*(min|minutes|mins)"#, options: .regularExpression) != nil
            || lower.range(of: #"in (\d+):(\d+)"#, options: .regularExpression) != nil

        if runMatch {
            var distance: Double?
            var durationMin = 30
            if let m = lower.range(of: #"(\d+(?:\.\d+)?)\s*(k|km|kilometers?)"#, options: .regularExpression) {
                distance = Double(String(lower[m]).components(separatedBy: CharacterSet.letters).first ?? "")! * 1000
            } else if let m = lower.range(of: #"(\d+(?:\.\d+)?)\s*(miles?|mi)"#, options: .regularExpression) {
                distance = Double(String(lower[m]).components(separatedBy: CharacterSet.letters).first ?? "")! * 1609.34
            }
            if let m = lower.range(of: #"in (\d+):(\d+)"#, options: .regularExpression) {
                let parts = lower[m].dropFirst(3).split(separator: ":")
                durationMin = (Int(parts[0]) ?? 0) + (Int(parts.last ?? "") ?? 0) > 59 ? (Int(parts[0]) ?? 0) : (Int(parts[0]) ?? 0)
            } else if let m = lower.range(of: #"in (\d+)\s*(min|minutes)"#, options: .regularExpression) {
                durationMin = Int(String(lower[m]).components(separatedBy: CharacterSet.letters).first ?? "") ?? 30
            }
            var paceStr: String?
            if let d = distance, d > 0 {
                paceStr = Fmt.pace(secPerKm: Double(durationMin * 60) / (d / 1000), units: c.units)
            }
            let load = ScoreEngine.sessionLoad(durationMin: durationMin, rpe: 7)
            return ParsedWorkout(log: .workout(kind: .cardio, title: "Run", durationMin: durationMin,
                                               distanceM: distance, rpe: 7, sport: nil),
                                 title: "Run", kind: .cardio, durationMin: durationMin,
                                 load: load, pace: paceStr)
        }
        if let m = lower.range(of: #"played (\w+)\s*(?:for\s+(\d+)\s*(min|minutes|hours?))?"#, options: .regularExpression) {
            let frag = String(lower[m])
            let sport = frag.components(separatedBy: " ").dropFirst().first ?? "sport"
            var minutes = 60
            if let dm = frag.range(of: #"\d+"#, options: .regularExpression) {
                minutes = Int(frag[dm]) ?? 60
                if frag.contains("hour") { minutes *= 60 }
            }
            let title = sport.prefix(1).uppercased() + sport.dropFirst()
            return ParsedWorkout(log: .workout(kind: .sport, title: title, durationMin: minutes,
                                               distanceM: nil, rpe: 7, sport: title),
                                 title: title, kind: .sport, durationMin: minutes,
                                 load: ScoreEngine.sessionLoad(durationMin: minutes, rpe: 7), pace: nil)
        }
        if containsAny(lower, ["did legs", "leg day", "did chest", "did back", "did arms", "trained", "workout done", "lifted"]) {
            let title = lower.contains("leg") ? "Leg day" : "Strength session"
            return ParsedWorkout(log: .workout(kind: .strength, title: title, durationMin: 45,
                                               distanceM: nil, rpe: 7, sport: nil),
                                 title: title, kind: .strength, durationMin: 45,
                                 load: ScoreEngine.sessionLoad(durationMin: 45, rpe: 7), pace: nil)
        }
        return nil
    }

    private func detectRestaurant(_ lower: String, context c: CoachContext) -> (name: String, time: Date)? {
        // "dinner at X", "lunch at X", "drinks at X", "@ X", or known names.
        let cal = Calendar.current
        let names = ["nobu", "sweetgreen", "chipotle", "cava", "shake shack", "steakhouse"]
        for name in names where lower.contains(name) {
            return (name.capitalized, eventTime(from: lower, context: c) ?? defaultMealTime(lower, now: c.now, cal: cal))
        }
        if let m = lower.range(of: #"(dinner|lunch|drinks|breakfast|brunch)\s+(at|@)\s+([a-z' ]+?)( at (\d{1,2})(:(\d{2}))?\s*(pm|am)?)?[.,!]?$"#,
                               options: .regularExpression) {
            let frag = String(lower[m])
            if let nameRange = frag.range(of: #"(?<=at\s|@\s)[a-z' ]+"#, options: .regularExpression) {
                var name = String(frag[nameRange])
                // Strip trailing time words.
                for w in [" at ", " pm", " am", " tonight", " today"] {
                    if let r = name.range(of: w) { name = String(name[..<r.lowerBound]) }
                }
                name = name.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && !["home", "work"].contains(name) {
                    return (name.prefix(1).uppercased() + name.dropFirst(),
                            eventTime(from: lower, context: c) ?? defaultMealTime(lower, now: c.now, cal: cal))
                }
            }
        }
        // Generic "work dinner" / "dinner tonight" — look at calendar.
        if containsAny(lower, ["dinner", "restaurant", "eating out", "drinks"]) {
            if let ev = c.events.first(where: {
                $0.title.lowercased().contains("dinner") || $0.location != nil
            }) {
                return (ev.location?.components(separatedBy: ",").first ?? ev.title, ev.start)
            }
            if containsAny(lower, ["dinner", "drinks", "eating out"]) {
                return ("Dinner", defaultMealTime(lower, now: c.now, cal: cal))
            }
        }
        return nil
    }

    private func eventTime(from lower: String, context c: CoachContext) -> Date? {
        // "at 7:30", "at 7pm"
        let cal = Calendar.current
        if let m = lower.range(of: #"(\d{1,2})(:(\d{2}))?\s*(pm|am)"#, options: .regularExpression) {
            let s = String(lower[m])
            let pm = s.contains("pm")
            let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let h = Int(digits[0]) {
                var hour = h % 12 + (pm ? 12 : 0)
                let min = digits.count > 1 ? Int(digits[1]) ?? 0 : 0
                var comps = cal.dateComponents([.year, .month, .day], from: c.now)
                comps.hour = hour; comps.minute = min
                return cal.date(from: comps)
            }
        } else if let m = lower.range(of: #"at (\d{1,2}):(\d{2})"#, options: .regularExpression) {
            let digits = String(lower[m]).dropFirst(3).split(separator: ":")
            var comps = cal.dateComponents([.year, .month, .day], from: c.now)
            comps.hour = Int(digits[0]); comps.minute = Int(digits.last ?? "")
            return cal.date(from: comps)
        }
        return nil
    }

    private func defaultMealTime(_ lower: String, now: Date, cal: Calendar) -> Date {
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = lower.contains("lunch") || lower.contains("brunch") ? 12 : 19
        comps.minute = lower.contains("lunch") ? 30 : 30
        return cal.date(from: comps) ?? now
    }

    // MARK: - Replies

    private func badSleepReply(context c: CoachContext, memories: [MemoryDraft]) -> CoachReply {
        var reply = CoachReply(text: "", memoryWrites: memories)
        guard let s = c.lastSleep else {
            reply.text = "No sleep logged last night — log it or connect Apple Health so I can adjust your plan around it."
            return reply
        }
        var detail = "\(Fmt.duration(minutes: s.asleepMin)) asleep, score \(s.score)"
        if let d = c.hrvDeltaPct { detail += ", HRV \(String(format: "%+.0f", d))% vs your baseline" }
        if let d = c.rhrDelta, abs(d) >= 2 { detail += ", resting HR \(d > 0 ? "+" : "")\(Int(d))" }
        detail += "."

        let swap: String
        if let sess = c.todaySession {
            let first = sess.blocks.first?.exercises.first?.name ?? "the hard sets"
            swap = "Swap \(sess.title) (\(first) especially) for mobility + 20 min Zone 2."
        } else {
            swap = "Keep today low intensity regardless."
        }
        reply.text = tone(c.tone,
            direct: "\(detail) \(swap) Caffeine cutoff 2 PM, lights out \(Fmt.clock(c.recommendedBedtime)) for \(Fmt.duration(minutes: c.sleepNeedMin)).",
            encouraging: "Rough one — \(detail) Don't sweat it: \(swap.lowercased()) Tomorrow's a new day.",
            nerd: "\(detail) Recovery score \(c.recoveryScore ?? 0). \(swap) Sleep need tonight: \(Fmt.duration(minutes: c.sleepNeedMin)); target lights-out \(Fmt.clock(c.recommendedBedtime)).")
        reply.actions.append(CoachAction(kind: .setReminder, title: "Wind-down reminder",
                                         subtitle: "45 min before lights out",
                                         params: ["title": "Wind down — screens off",
                                                  "body": "Lights out \(Fmt.clock(c.recommendedBedtime)).",
                                                  "fireISO": iso(c.recommendedBedtime.addingTimeInterval(-45 * 60))]))
        reply.actions.append(CoachAction(kind: .scheduleWorkout, title: "Recovery session",
                                         subtitle: "Mobility + 20 min Zone 2",
                                         params: ["title": "Atlas: Recovery",
                                                  "durationMin": "35",
                                                  "notes": "Mobility circuit + 20 min Zone 2 cardio."]))
        return reply
    }

    private func dinnerReply(restaurant: (name: String, time: Date), text: String,
                             context c: CoachContext, memories: [MemoryDraft]) -> CoachReply {
        var reply = CoachReply(text: "", memoryWrites: memories)
        let timeStr = Fmt.clock(restaurant.time)
        let lunchKcal = Int((c.remaining.kcal * 0.35 / 10).rounded() * 10)
        let lunchProtein = max(40, c.targets.proteinG / 3)
        let windowNote: String
        if let w = c.eatingWindow {
            windowNote = w.isOpen
                ? "\(restaurant.name) at \(timeStr) is inside your window"
                : "\(restaurant.name) at \(timeStr) is past your \(Fmt.clock(w.closes)) close — eat earlier there"
        } else {
            windowNote = "\(restaurant.name) at \(timeStr)"
        }
        let guide = GamePlanEngine.orderGuideBody(for: restaurant.name)
        reply.text = "\(windowNote). You have \(Fmt.kcal(c.remaining.kcal)) kcal and \(Int(c.remaining.protein)) g protein left, so keep lunch ~\(Fmt.kcal(Double(lunchKcal))) kcal / \(lunchProtein) g protein. Order guide: \(guide.components(separatedBy: "\n").joined(separator: ", ")). You need lights out by \(Fmt.clock(c.recommendedBedtime)) for \(Fmt.duration(minutes: c.sleepNeedMin)) — late rich meals push deep sleep down."
        reply.actions.append(CoachAction(kind: .reserveTable,
                                         title: "Reserve \(restaurant.name)",
                                         subtitle: "Tonight · \(timeStr)",
                                         params: ["restaurant": restaurant.name, "partySize": "2",
                                                  "dateISO": iso(restaurant.time),
                                                  "orderGuide": guide]))
        reply.actions.append(CoachAction(kind: .orderMeal, title: "Lunch that fits",
                                         subtitle: "~\(Fmt.kcal(Double(lunchKcal))) kcal · \(lunchProtein) g protein",
                                         params: ["query": "high protein bowl", "provider": "doordash",
                                                  "suggestion": "Double-protein bowl, rice light\nEdamame side",
                                                  "kcal": "\(lunchKcal)", "protein": "\(lunchProtein)"]))
        reply.actions.append(CoachAction(kind: .setReminder, title: "Wind-down reminder",
                                         subtitle: "Lights out \(Fmt.clock(c.recommendedBedtime))",
                                         params: ["title": "Wind down", "body": "Aim for lights out at \(Fmt.clock(c.recommendedBedtime)).",
                                                  "fireISO": iso(c.recommendedBedtime.addingTimeInterval(-45 * 60))]))
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "h:mm a"
        reply.memoryWrites.append(MemoryDraft(kind: .task,
                                              text: "\(restaurant.name) tonight \(dateFmt.string(from: restaurant.time))",
                                              dueDate: restaurant.time))
        return reply
    }

    private func orderReply(context c: CoachContext, memories: [MemoryDraft]) -> CoachReply {
        var reply = CoachReply(text: "", memoryWrites: memories)
        let kcal = Int(c.remaining.kcal * 0.4)
        let protein = Int(c.remaining.protein * 0.4)
        reply.text = "You have \(Fmt.kcal(c.remaining.kcal)) kcal and \(Int(c.remaining.protein)) g protein left today. Order something in the \(Fmt.kcal(Double(kcal))) kcal, \(protein)+ g protein range — a double-protein bowl does it."
        reply.actions.append(CoachAction(kind: .orderMeal, title: "Order lunch",
                                         subtitle: "~\(Fmt.kcal(Double(kcal))) kcal · \(protein)+ g protein",
                                         params: ["query": "high protein bowl", "provider": "doordash",
                                                  "suggestion": "Chipotle-style bowl, double chicken\nLight rice, beans, salsa",
                                                  "kcal": "\(kcal)", "protein": "\(protein)"]))
        return reply
    }

    private func rescheduleReply(context c: CoachContext, memories: [MemoryDraft]) -> CoachReply {
        var reply = CoachReply(text: "", memoryWrites: memories)
        guard let s = c.todaySession else {
            reply.text = "Nothing planned today anyway — take the rest."
            return reply
        }
        let next = c.weekSplit.filter { $0.weekday > s.weekday }.first ?? c.weekSplit.first
        reply.text = "Fine — drop \(s.title) today. Don't stack it: pick it back up with \(next?.title ?? "the next session"). If you can salvage 20 min, do the plyo block only."
        reply.actions.append(CoachAction(kind: .scheduleWorkout, title: "Schedule \(next?.title ?? "next session")",
                                         subtitle: "\(next?.durationMin ?? 45) min",
                                         params: ["title": "Atlas: \(next?.title ?? "Session")",
                                                  "durationMin": "\(next?.durationMin ?? 45)",
                                                  "notes": next?.blocks.map { "\($0.title): \($0.exercises.map(\.name).joined(separator: ", "))" }.joined(separator: "\n") ?? ""]))
        return reply
    }

    private func statusReply(context c: CoachContext) -> String {
        guard let g = c.goal else {
            return "No active goal yet — finish onboarding and I'll start tracking."
        }
        let cur = Fmt.metric(g.current, metric: g.metric, units: c.units, customUnit: g.customUnit)
        let tgt = Fmt.metric(g.target, metric: g.metric, units: c.units, customUnit: g.customUnit)
        var parts = ["\(cur) of \(tgt), \(g.daysLeft) days left — \(g.projection.status.title.lowercased())."]
        if let d = g.projection.projectedDate {
            parts.append("Projected \(Fmt.date(d)) (\(g.projection.daysVsTarget >= 0 ? "\(g.projection.daysVsTarget) days early" : "\(-g.projection.daysVsTarget) days late")).")
        }
        let week = c.recentWorkouts.filter { c.now.timeIntervalSince($0.date) <= 7 * 86400 }
        parts.append("This week: \(week.count) sessions, \(Int(c.eaten.protein)) of \(c.targets.proteinG) g protein so far today.")
        return parts.joined(separator: " ")
    }

    private func planExplanation(context c: CoachContext) -> String {
        var parts: [String] = []
        if !c.plan.rationale.isEmpty { parts.append(c.plan.rationale) }
        parts.append("\(Fmt.kcal(Double(c.targets.kcal))) kcal/day (\(c.targets.proteinG)P/\(c.targets.carbsG)C/\(c.targets.fatG)F)")
        parts.append("\(c.weekSplit.count) sessions/week")
        parts.append("sleep target \(Fmt.duration(minutes: c.sleepNeedMin))")
        if let s = c.todaySession { parts.append("today: \(s.title)") }
        return parts.joined(separator: ". ") + "."
    }

    private func fallbackSummary(context c: CoachContext) -> String {
        var parts: [String] = []
        if let s = c.lastSleep {
            parts.append("sleep \(Fmt.duration(minutes: s.asleepMin)) (score \(s.score))")
        }
        parts.append("\(Fmt.kcal(c.eaten.kcal))/\(Fmt.kcal(Double(c.targets.kcal))) kcal, \(Int(c.eaten.protein))/\(c.targets.proteinG) g protein")
        if let sess = c.todaySession { parts.append("\(sess.title) today") }
        else { parts.append("rest day") }
        return "Today: " + parts.joined(separator: "; ") + ". Ask me to log a meal, plan around a dinner, or adjust the session."
    }

    // MARK: - Tone & utils

    private func tone(_ t: CoachTone, direct: String, encouraging: String, nerd: String) -> String {
        switch t {
        case .direct: return direct
        case .encouraging: return encouraging
        case .dataNerd: return nerd
        }
    }

    private func tgtStr(_ s: String) -> String { s }

    private func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private func iso(_ d: Date) -> String {
        ISO8601DateFormatter().string(from: d)
    }
}
