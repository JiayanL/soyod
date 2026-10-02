import Foundation

/// Collects tool side-effects (actions, memories, logs) during a turn.
nonisolated final class CoachToolCollector: @unchecked Sendable {
    var actions: [CoachAction] = []
    var memoryWrites: [MemoryDraft] = []
    var logs: [CoachLog] = []
}

#if canImport(FoundationModels)
import FoundationModels

/// Apple Intelligence coach. Used only when the system model is available;
/// on any error the caller falls back to RuleBasedCoach.
@available(iOS 26.0, *)
final class FoundationModelsCoach: CoachAgent {
    let displayName = "Apple Intelligence"
    private let fallback = RuleBasedCoach()

    func respond(to text: String, history: [ChatTurn], context c: CoachContext) async throws -> CoachReply {
        let collector = CoachToolCollector()
        let tools: [any Tool] = Self.makeTools(context: c, collector: collector)
        let session = LanguageModelSession(tools: tools, instructions: Self.instructions(for: c))
        let response = try await session.respond(to: text)
        var reply = CoachReply(text: response.content)
        reply.actions = collector.actions
        reply.memoryWrites = collector.memoryWrites + MemoryExtractor.extract(from: text, now: c.now)
        reply.logs = collector.logs
        return reply
    }

    /// Optional polish pass: rewrite directive copy in the user's tone.
    /// Facts (numbers/times) must be preserved.
    func rewrite(directives: [Directive], tone: CoachTone, context c: CoachContext) async -> [Directive] {
        let session = LanguageModelSession(instructions: """
            Rewrite each directive's title (≤90 chars) and detail (≤140 chars) in a \(tone.title.lowercased()) coach voice. \
            Preserve every number, time, and fact exactly. Reply with JSON: [{"i":0,"title":"...","detail":"..."}]
            """)
        let payload = directives.enumerated().map {
            "{\"i\":\($0.offset),\"title\":\(Self.jsonString($0.element.title)),\"detail\":\(Self.jsonString($0.element.detail))}"
        }.joined(separator: ",")
        guard let r = try? await session.respond(to: "[" + payload + "]") else { return directives }
        struct Rewrite: Codable { var i: Int; var title: String; var detail: String }
        guard let data = r.content.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([Rewrite].self, from: data) else { return directives }
        var out = directives
        for p in parsed where p.i < out.count && !p.title.isEmpty {
            out[p.i].title = p.title
            out[p.i].detail = p.detail
        }
        return out
    }

    // MARK: - Instructions

    static func instructions(for c: CoachContext) -> String {
        var lines: [String] = [
            "You are Atlas, an elite fitness concierge for \(c.userName.isEmpty ? "the athlete" : c.userName).",
            "Tone: \(c.tone.title). Be tactical, specific, ≤ 90 words. Cite real numbers and times.",
            "No platitudes. At most one emoji, only when celebrating.",
        ]
        if let g = c.goal {
            lines.append("Goal: \(g.title) — \(Fmt.metric(g.current, metric: g.metric, units: c.units)) → \(Fmt.metric(g.target, metric: g.metric, units: c.units)), \(g.daysLeft) days left, \(g.projection.status.title.lowercased()).")
        }
        lines.append("Fuel today: \(Fmt.kcal(c.eaten.kcal))/\(Fmt.kcal(Double(c.targets.kcal))) kcal, protein \(Int(c.eaten.protein))/\(c.targets.proteinG) g.")
        if let s = c.lastSleep {
            lines.append("Last night: \(Fmt.duration(minutes: s.asleepMin)) asleep, score \(s.score). Need tonight: \(Fmt.duration(minutes: c.sleepNeedMin)), bed \(Fmt.clock(c.recommendedBedtime)).")
        }
        if let sess = c.todaySession {
            lines.append("Today's session: \(sess.title) (\(sess.durationMin) min, \(sess.focus)).")
        }
        if let w = c.eatingWindow {
            lines.append("Eating window: \(Fmt.clock(w.opens))–\(Fmt.clock(w.closes)) (\(w.isOpen ? "open" : "closed")).")
        }
        let evs = c.events.map { "\($0.title) \(Fmt.clock($0.start))" }.joined(separator: "; ")
        if !evs.isEmpty { lines.append("Calendar today: \(evs).") }
        let mems = c.memories.prefix(8).map(\.text).joined(separator: " | ")
        if !mems.isEmpty { lines.append("Memories: \(mems).") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Tools

    static func makeTools(context c: CoachContext, collector: CoachToolCollector) -> [any Tool] {
        [GetTodaySummaryTool(context: c), GetGoalStatusTool(context: c),
         LogMealTool(collector: collector), LogWorkoutTool(collector: collector),
         RememberTool(collector: collector), ProposeReservationTool(collector: collector),
         ProposeDeliveryOrderTool(collector: collector), ScheduleWorkoutTool(collector: collector),
         SetReminderTool(collector: collector)]
    }

    private static func jsonString(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n") + "\""
    }
}

// MARK: - Tools

@available(iOS 26.0, *)
struct GetTodaySummaryTool: Tool {
    let name = "getTodaySummary"
    let description = "Sleep, nutrition eaten/remaining, today's session, eating window, calendar."
    let context: CoachContext

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        var parts = ["Eaten \(Fmt.kcal(context.eaten.kcal))/\(Fmt.kcal(Double(context.targets.kcal))) kcal, \(Int(context.eaten.protein))/\(context.targets.proteinG) g protein"]
        if let s = context.lastSleep {
            parts.append("sleep \(Fmt.duration(minutes: s.asleepMin)) score \(s.score)")
        }
        if let sess = context.todaySession {
            parts.append("session \(sess.title) \(sess.durationMin) min")
        }
        return parts.joined(separator: ". ")
    }
}

@available(iOS 26.0, *)
struct GetGoalStatusTool: Tool {
    let name = "getGoalStatus"
    let description = "Goal baseline/current/target, days left, projection."
    let context: CoachContext

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        guard let g = context.goal else { return "No active goal." }
        return "\(g.title): \(Fmt.metric(g.current, metric: g.metric, units: context.units)) of \(Fmt.metric(g.target, metric: g.metric, units: context.units)), \(g.daysLeft) days left, \(g.projection.status.title)."
    }
}

@available(iOS 26.0, *)
struct LogMealTool: Tool {
    let name = "logMeal"
    let description = "Log a meal the user describes eating."
    let collector: CoachToolCollector

    @Generable
    struct Arguments {
        var description: String
    }

    func call(arguments: Arguments) async throws -> String {
        let items = FoodTextParser.parse(arguments.description)
        guard !items.isEmpty else { return "Couldn't parse any foods." }
        collector.logs.append(.meal(title: arguments.description,
                                  mealType: AppState.defaultMealType(at: AppClock.now),
                                  items: items))
        let kcal = items.reduce(0) { $0 + $1.kcal }
        return "Logged \(items.count) items, \(Fmt.kcal(kcal)) kcal."
    }
}

@available(iOS 26.0, *)
struct LogWorkoutTool: Tool {
    let name = "logWorkout"
    let description = "Log a workout the user completed."
    let collector: CoachToolCollector

    @Generable
    struct Arguments {
        var title: String
        var durationMin: Int
        var kind: String
    }

    func call(arguments: Arguments) async throws -> String {
        let kind = WorkoutKind(rawValue: arguments.kind) ?? .strength
        collector.logs.append(.workout(kind: kind, title: arguments.title,
                                       durationMin: arguments.durationMin,
                                       distanceM: nil, rpe: nil, sport: nil))
        return "Logged \(arguments.title), \(arguments.durationMin) min."
    }
}

@available(iOS 26.0, *)
struct RememberTool: Tool {
    let name = "remember"
    let description = "Store a long-term fact, preference, or task about the user."
    let collector: CoachToolCollector

    @Generable
    struct Arguments {
        var kind: String
        var text: String
    }

    func call(arguments: Arguments) async throws -> String {
        collector.memoryWrites.append(MemoryDraft(kind: MemoryKind(rawValue: arguments.kind) ?? .fact,
                                                  text: arguments.text, dueDate: nil))
        return "Remembered."
    }
}

@available(iOS 26.0, *)
struct ProposeReservationTool: Tool {
    let name = "proposeReservation"
    let description = "Propose a restaurant reservation action card."
    let collector: CoachToolCollector

    @Generable
    struct Arguments {
        var restaurant: String
        var partySize: Int
        var dateISO: String
    }

    func call(arguments: Arguments) async throws -> String {
        // Bare hours are evening in dinner context ("7:30 tonight" → 19:30).
        var dateISO = arguments.dateISO
        if let d = ISO8601DateFormatter().date(from: dateISO) {
            let h = Calendar.current.component(.hour, from: d)
            if h >= 1 && h <= 11 {
                dateISO = ISO8601DateFormatter().string(from: d.addingTimeInterval(12 * 3600))
            }
        }
        collector.actions.append(CoachAction(kind: .reserveTable,
                                             title: "Reserve \(arguments.restaurant)",
                                             subtitle: "Party of \(arguments.partySize)",
                                             params: ["restaurant": arguments.restaurant,
                                                      "partySize": "\(arguments.partySize)",
                                                      "dateISO": dateISO,
                                                      "orderGuide": GamePlanEngine.orderGuideBody(for: arguments.restaurant)]))
        return "Reservation card proposed."
    }
}

@available(iOS 26.0, *)
struct ProposeDeliveryOrderTool: Tool {
    let name = "proposeDeliveryOrder"
    let description = "Propose a food-delivery order action card fitting remaining macros."
    let collector: CoachToolCollector

    @Generable
    struct Arguments {
        var query: String
        var suggestion: String
    }

    func call(arguments: Arguments) async throws -> String {
        collector.actions.append(CoachAction(kind: .orderMeal,
                                             title: "Order \(arguments.query)",
                                             subtitle: arguments.suggestion,
                                             params: ["query": arguments.query, "provider": "doordash",
                                                      "suggestion": arguments.suggestion]))
        return "Order card proposed."
    }
}

@available(iOS 26.0, *)
struct ScheduleWorkoutTool: Tool {
    let name = "scheduleWorkout"
    let description = "Propose scheduling a workout on the user's calendar."
    let collector: CoachToolCollector

    @Generable
    struct Arguments {
        var title: String
        var durationMin: Int
        var startISO: String?
    }

    func call(arguments: Arguments) async throws -> String {
        var params = ["title": arguments.title, "durationMin": "\(arguments.durationMin)"]
        params["startISO"] = arguments.startISO
        collector.actions.append(CoachAction(kind: .scheduleWorkout,
                                             title: "Schedule \(arguments.title)",
                                             subtitle: "\(arguments.durationMin) min",
                                             params: params))
        return "Schedule card proposed."
    }
}

@available(iOS 26.0, *)
struct SetReminderTool: Tool {
    let name = "setReminder"
    let description = "Propose a local notification reminder."
    let collector: CoachToolCollector

    @Generable
    struct Arguments {
        var title: String
        var body: String
        var fireISO: String
    }

    func call(arguments: Arguments) async throws -> String {
        collector.actions.append(CoachAction(kind: .setReminder,
                                             title: arguments.title, subtitle: arguments.body,
                                             params: ["title": arguments.title, "body": arguments.body,
                                                      "fireISO": arguments.fireISO]))
        return "Reminder card proposed."
    }
}
#endif
