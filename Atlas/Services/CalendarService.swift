import Foundation
import EventKit

@Observable
final class CalendarService {
    enum Status: String, Sendable { case notDetermined, granted, denied, writeOnly, unavailable }

    private(set) var status: Status = .notDetermined
    private let store = EKEventStore()

    init() {
        refreshStatus()
    }

    private func refreshStatus() {
        let auth = EKEventStore.authorizationStatus(for: .event)
        switch auth {
        case .fullAccess: status = .granted
        case .writeOnly: status = .writeOnly
        case .denied, .restricted: status = .denied
        case .notDetermined: status = .notDetermined
        @unknown default: status = .unavailable
        }
    }

    @discardableResult
    func requestAccess() async -> Bool {
        guard !LaunchOptions.current.denyPermissions else {
            status = .denied
            return false
        }
        do {
            let granted = try await store.requestFullAccessToEvents()
            refreshStatus()
            return granted
        } catch {
            status = .denied
            return false
        }
    }

    /// Events on `day`. When access isn't granted and the profile uses sample
    /// data, returns the synthetic sample events; otherwise empty.
    func events(on day: Date, isSampleData: Bool = false) -> [CalendarEventInfo] {
        var cal = Calendar.current
        cal.timeZone = .current
        if status == .granted || status == .writeOnly {
            let start = cal.startOfDay(for: day)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            return store.events(matching: predicate).map {
                CalendarEventInfo(id: $0.eventIdentifier ?? UUID().uuidString,
                                  title: $0.title ?? "Event",
                                  start: $0.startDate, end: $0.endDate,
                                  location: $0.location, isSynthetic: false)
            }
        }
        guard isSampleData else { return [] }
        return syntheticEvents(on: day, cal: cal)
    }

    /// Sample-persona events used when Calendar access is off.
    private func syntheticEvents(on day: Date, cal: Calendar) -> [CalendarEventInfo] {
        var out: [CalendarEventInfo] = []
        let today = cal.startOfDay(for: day)
        func at(_ h: Int, _ m: Int, _ dayOffset: Int = 0) -> Date {
            today.addingTimeInterval(TimeInterval(dayOffset * 86400 + h * 3600 + m * 60))
        }
        out.append(CalendarEventInfo(
            id: "synth-nobu-\(Int(today.timeIntervalSince1970))",
            title: "Dinner at Nobu", start: at(19, 30), end: at(21, 30),
            location: "Nobu, 105 Hudson St", isSynthetic: true))
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        out.append(CalendarEventInfo(
            id: "synth-standup-\(Int(tomorrow.timeIntervalSince1970))",
            title: "Team standup",
            start: tomorrow.addingTimeInterval(9 * 3600),
            end: tomorrow.addingTimeInterval(9.5 * 3600),
            location: nil, isSynthetic: true))
        return out
    }

    /// Finds the first free 60-min slot between 6:00 and 21:00 today/tomorrow
    /// and writes an event. Returns the scheduled start.
    @discardableResult
    func addWorkout(title: String, notes: String?, durationMin: Int,
                    preferredStart: Date? = nil) async throws -> Date {
        if status != .granted && status != .writeOnly {
            _ = await requestAccess()
        }
        guard status == .granted || status == .writeOnly else {
            throw ActionError.calendarDenied
        }
        var cal = Calendar.current
        cal.timeZone = .current
        let duration = TimeInterval(durationMin * 60)

        // Candidate slots, in preference order.
        var candidates: [Date] = []
        if let p = preferredStart { candidates.append(p) }
        for dayOffset in 0...1 {
            let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: AppClock.now))!
            for hour in [18, 7, 12, 17, 6, 19, 20] {
                candidates.append(day.addingTimeInterval(TimeInterval(hour * 3600)))
            }
        }
        let existing = events(on: AppClock.now) + events(on: AppClock.now.addingTimeInterval(86400))
        let now = AppClock.now
        var chosen: Date?
        for slot in candidates where slot > now {
            let slotEnd = slot.addingTimeInterval(duration)
            let slotEndOfDay = cal.startOfDay(for: slot).addingTimeInterval(21 * 3600)
            guard slotEnd <= slotEndOfDay else { continue }
            let conflict = existing.contains { ev in
                ev.start < slotEnd && ev.end > slot
            }
            if !conflict { chosen = slot; break }
        }
        guard let start = chosen else { throw ActionError.noFreeSlot }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.startDate = start
        event.endDate = start.addingTimeInterval(duration)
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
        return start
    }
}

enum ActionError: Error, Sendable {
    case calendarDenied
    case noFreeSlot
    case notificationsDenied
}
