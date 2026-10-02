import Foundation
import UserNotifications

final class NotificationService: Sendable {
    enum Status: String, Sendable { case notDetermined, granted, denied }

    func status() async -> Status {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        switch s.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard !LaunchOptions.current.denyPermissions else { return false }
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func schedule(id: String, title: String, body: String, at date: Date) async throws {
        if await status() == .notDetermined {
            _ = await requestAuthorization()
        }
        guard await status() == .granted else { throw ActionError.notificationsDenied }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(req)
    }
}
