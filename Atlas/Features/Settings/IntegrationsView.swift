import SwiftUI

/// Connection status for Apple Health, Calendar, Notifications and partner deep links.
struct IntegrationsView: View {
    @Environment(AppState.self) private var app
    @State private var notificationStatus: NotificationService.Status = .notDetermined
    @State private var importing = false

    var body: some View {
        List {
            Section {
                IntegrationRow(symbol: "heart.fill", color: Theme.Palette.train, title: "Apple Health",
                               detail: healthDetail, state: healthState, actionTitle: healthActionTitle, busy: importing) {
                    importing = true
                    Task {
                        _ = await app.health.requestAuthorization()
                        _ = await app.importHealth()
                        importing = false
                    }
                }
                .accessibilityIdentifier("integration-health")
                IntegrationRow(symbol: "calendar", color: Theme.Palette.train, title: "Calendar",
                               detail: calendarDetail, state: calendarState, actionTitle: app.calendar.status == .granted ? nil : "Connect") {
                    Task { _ = await app.calendar.requestAccess(); app.refresh() }
                }
                IntegrationRow(symbol: "bell.badge.fill", color: Theme.Palette.fuel, title: "Notifications",
                               detail: "Reminders for meals, bedtime and sessions you ask Atlas to set.",
                               state: notificationStatus == .granted ? .connected : notificationStatus == .denied ? .denied : .off,
                               actionTitle: notificationStatus == .granted ? nil : "Allow") {
                    Task {
                        _ = await app.notifications.requestAuthorization()
                        notificationStatus = await app.notifications.status()
                    }
                }
            } header: { header("On this iPhone") } footer: {
                if healthState == .denied || calendarState == .denied || notificationStatus == .denied {
                    Text("Denied permissions can be changed in iOS Settings → Atlas. Everything still works with manual logging.")
                        .textStyle(.footnote)
                }
            }

            Section {
                partner("fork.knife", "Reservations", "OpenTable and Resy open in their app or on the web, prefilled with party, date and time.")
                partner("bag.fill", "Delivery", "DoorDash and Uber Eats open to a search for the dish Atlas recommends.")
                partner("calendar.badge.plus", "Training blocks", "Atlas finds a free slot and adds sessions to your calendar.")
            } header: { header("Actions") }

            Section {
                HStack(spacing: Theme.Space.s) {
                    IconDisk(symbol: "sparkles", color: Theme.Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coach engine").textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                        Text(app.engineStatus.name).textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            } header: { header("Intelligence") }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.bg)
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .task { notificationStatus = await app.notifications.status() }
    }

    private var healthState: IntegrationRow.State {
        if !app.health.isAvailable || app.launch.denyPermissions { return .denied }
        return app.health.status == .requested ? .connected : .off
    }

    private var healthActionTitle: String? {
        healthState == .connected || healthState == .denied ? nil : "Connect"
    }

    private var healthDetail: String {
        if let s = app.lastImport, healthState == .connected {
            return "Imported \(s.sleepNights) nights, \(s.workouts) workouts, \(s.stepDays) days of steps."
        }
        if healthState == .denied { return "Not available — sleep and workouts can be logged manually." }
        return "Sleep stages, HRV, resting HR, workouts, steps and body measurements."
    }

    private var calendarState: IntegrationRow.State {
        switch app.calendar.status {
        case .granted, .writeOnly: .connected
        case .denied, .unavailable: .denied
        case .notDetermined: .off
        }
    }

    private var calendarDetail: String {
        calendarState == .denied
            ? "Atlas uses sample events instead. Calendar actions open a prefilled event."
            : "Dinners and meetings shape your Game Plan. Atlas can add workouts."
    }

    private func header(_ t: String) -> some View {
        Text(t).textStyle(.micro).foregroundStyle(Theme.Palette.textSecondary)
    }

    private func partner(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            IconDisk(symbol: symbol, color: Theme.Palette.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                Text(detail).textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Theme.Space.xxs)
        .listRowBackground(Theme.Palette.surface)
        .accessibilityElement(children: .combine)
    }
}

struct IntegrationRow: View {
    enum State { case connected, off, denied }

    let symbol: String
    let color: Color
    let title: String
    let detail: String
    let state: State
    var actionTitle: String?
    var busy = false
    var action: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            IconDisk(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                HStack(spacing: Theme.Space.xs) {
                    Text(title).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                    StatusChip(text: stateText, dot: stateColor)
                }
                Text(detail).textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let actionTitle {
                    Button(action: action) {
                        if busy { ProgressView() } else { Text(actionTitle) }
                    }
                    .buttonStyle(.atlasPrimaryCompact)
                    .padding(.top, Theme.Space.xxs)
                    .disabled(busy)
                }
            }
        }
        .padding(.vertical, Theme.Space.xxs)
        .listRowBackground(Theme.Palette.surface)
    }

    private var stateText: String {
        switch state {
        case .connected: "Connected"
        case .off: "Not connected"
        case .denied: "Unavailable"
        }
    }

    private var stateColor: Color {
        switch state {
        case .connected: Theme.Palette.recovery
        case .off: Theme.Palette.textTertiary
        case .denied: Theme.Palette.fuel
        }
    }
}
