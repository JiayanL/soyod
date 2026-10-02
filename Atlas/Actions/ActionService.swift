import Foundation
import UIKit

enum ActionOutcome: Sendable {
    case openedURL(URL)
    case addedToCalendar(Date)
    case reminderScheduled(Date)
    case logged
    case failed(String)
}

/// Performs agent actions (deep links, calendar writes, reminders).
/// Food/meal logging is handled by AppState directly.
final class ActionService {
    let calendar: CalendarService
    let notifications: NotificationService

    init(calendar: CalendarService, notifications: NotificationService) {
        self.calendar = calendar
        self.notifications = notifications
    }

    /// URL for an action, if it opens a deep link (also used in tests).
    func url(for action: CoachAction) -> URL? {
        switch action.kind {
        case .reserveTable:
            guard let restaurant = action.params["restaurant"] else { return nil }
            let party = Int(action.params["partySize"] ?? "2") ?? 2
            let date = action.params["dateISO"].flatMap { ISO8601DateFormatter().date(from: $0) } ?? AppClock.now
            if action.params["provider"] == "resy" {
                return ActionURLBuilder.resy(restaurant: restaurant, partySize: party,
                                             date: date, city: action.params["city"] ?? "new-york")
            }
            return ActionURLBuilder.openTable(restaurant: restaurant, partySize: party, date: date)
        case .orderMeal:
            let query = action.params["query"] ?? "healthy food"
            switch action.params["provider"] {
            case "ubereats": return ActionURLBuilder.uberEats(query: query)
            default: return ActionURLBuilder.doorDash(query: query)
            }
        default:
            return nil
        }
    }

    @MainActor
    func perform(_ action: CoachAction) async -> ActionOutcome {
        switch action.kind {
        case .reserveTable, .orderMeal:
            guard let url = url(for: action) else {
                return .failed("Couldn't build a link for that.")
            }
            await UIApplication.shared.open(url)
            return .openedURL(url)

        case .scheduleWorkout:
            let title = action.params["title"] ?? "Atlas workout"
            let duration = Int(action.params["durationMin"] ?? "60") ?? 60
            let preferred = action.params["startISO"].flatMap { ISO8601DateFormatter().date(from: $0) }
            do {
                let start = try await calendar.addWorkout(
                    title: title, notes: action.params["notes"],
                    durationMin: duration, preferredStart: preferred)
                return .addedToCalendar(start)
            } catch {
                // Calendar off → schedule a local reminder at the slot instead.
                let fire = preferred ?? defaultSlot()
                do {
                    try await notifications.schedule(
                        id: action.id.uuidString, title: title,
                        body: "Time to train — \(Fmt.duration(minutes: duration)) session.",
                        at: fire)
                    return .reminderScheduled(fire)
                } catch {
                    return .failed("Calendar is off — couldn't set a reminder either.")
                }
            }

        case .setReminder:
            guard let iso = action.params["fireISO"],
                  let fire = ISO8601DateFormatter().date(from: iso) else {
                return .failed("No time set for that reminder.")
            }
            do {
                try await notifications.schedule(
                    id: action.id.uuidString,
                    title: action.params["title"] ?? action.title,
                    body: action.params["body"] ?? action.subtitle,
                    at: fire)
                return .reminderScheduled(fire)
            } catch {
                return .failed("Notifications are off. Turn them on in Settings.")
            }

        case .logMeal:
            // Applied by AppState (needs the ModelContext).
            return .logged
        }
    }

    private func defaultSlot() -> Date {
        AppClock.now.addingTimeInterval(3600)
    }
}
