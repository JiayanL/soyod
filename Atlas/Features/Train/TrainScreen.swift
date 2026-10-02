import SwiftUI
import SwiftData

struct TrainScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    TodayHero()
                    WeekStrip(workouts: workouts)
                    LoadCard()
                    recent
                    PRBoard(workouts: workouts)
                }
                .gutter()
                .padding(.bottom, Theme.Space.xxxl)
            }
            .atlasScreenBackground()
            .safeAreaInset(edge: .bottom) {
                if let session = app.context.todaySession {
                    Button {
                        router.sheet = .logger(session)
                    } label: {
                        Text(app.context.completedToday.isEmpty ? "Start \(session.title)" : "Log another session")
                            .lineLimit(1)
                    }
                    .buttonStyle(.atlasPrimary)
                    .accessibilityIdentifier("startWorkout")
                    .gutter()
                    .padding(.top, Theme.Space.s)
                    .padding(.bottom, Theme.Space.xs)
                    .bottomBarScrim()
                }
            }
            .navigationTitle("Train")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { router.sheet = .logger(nil) } label: { Label("Strength workout", systemImage: "dumbbell") }
                        Button { router.sheet = .cardio } label: { Label("Cardio or sport", systemImage: "figure.run") }
                    } label: {
                        Image(systemName: "plus").icon(Theme.Icon.regular)
                    }
                    .accessibilityLabel("Log workout")
                    .accessibilityIdentifier("logWorkoutMenu")
                }
            }
        }
    }

    @ViewBuilder
    private var recent: some View {
        let list = Array(workouts.prefix(6))
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader(title: "Recent", trailing: "Log cardio") { router.sheet = .cardio }
            if list.isEmpty {
                EmptyStateView(symbol: "figure.run", title: "No workouts yet", message: "Start today's session or log a run, ride or game.", ctaTitle: "Log a run") {
                    router.sheet = .cardio
                }
                .atlasCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(list) { w in
                        WorkoutRow(workout: w)
                        if w.id != list.last?.id { Hairline(leading: 44) }
                    }
                }
                .atlasCard()
            }
        }
    }
}

// MARK: - Today hero (Ladder-style)

private struct TodayHero: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        let ctx = app.context
        let done = !ctx.completedToday.isEmpty
        let lowRecovery = (ctx.recoveryScore ?? 100) < 50
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                MicroLabel("Today · \(ctx.now.formatted(.dateTime.weekday(.wide)))", color: Theme.Palette.train)
                Spacer()
                if let s = ctx.todaySession {
                    Text("\(s.durationMin) min").textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            if let session = ctx.todaySession {
                Text(session.title.uppercased())
                    .textStyle(.display)
                    .fontWeight(.heavy)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(session.focus)
                    .textStyle(.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if lowRecovery && !done {
                    HStack(alignment: .top, spacing: Theme.Space.xs) {
                        Image(systemName: "exclamationmark.triangle.fill").icon(Theme.Icon.small).foregroundStyle(Theme.Palette.fuel)
                        Text("Recovery is \(ctx.recoveryScore ?? 0)%. Atlas suggests cutting the plyometrics and keeping strength at RPE 6.")
                            .textStyle(.footnote)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Theme.Space.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Palette.fuel.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.small, style: .continuous))
                }
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    ForEach(session.blocks) { block in
                        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                            Text(block.title).textStyle(.micro).foregroundStyle(Theme.Palette.textTertiary)
                            ForEach(block.exercises) { ex in
                                HStack {
                                    Text(ex.name).textStyle(.callout).foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
                                    Spacer()
                                    Text("\(ex.sets) × \(ex.reps)").textStyle(.metricS).foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("REST DAY")
                    .textStyle(.display)
                    .fontWeight(.heavy)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Recovery is training too. A 20-minute walk and mobility keep you fresh for the next session.")
                    .textStyle(.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Space.s) {
                    Button("Log a walk") { router.sheet = .cardio }
                        .buttonStyle(.atlasSecondary)
                    Button("Free workout") { router.sheet = .logger(nil) }
                        .buttonStyle(.atlasPrimary)
                }
            }
        }
        .atlasCard(padding: Theme.Space.hero)
    }
}

// MARK: - Week strip

private struct WeekStrip: View {
    let workouts: [Workout]
    @Environment(AppState.self) private var app

    var body: some View {
        let cal = Calendar.mondayFirst
        let now = app.context.now
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            MicroLabel("This week")
            HStack(spacing: Theme.Space.xxs) {
                ForEach(0..<7, id: \.self) { i in
                    let day = cal.date(byAdding: .day, value: i, to: weekStart) ?? now
                    let planned = app.context.weekSplit.first { $0.weekday == i + 1 }
                    let doneKinds = workouts.filter { cal.isDate($0.date, inSameDayAs: day) }.map(\.kind)
                    let isToday = cal.isDate(day, inSameDayAs: now)
                    VStack(spacing: Theme.Space.xs) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .textStyle(.micro)
                            .foregroundStyle(isToday ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                        Text(day.formatted(.dateTime.day()))
                            .textStyle(.metricS)
                            .foregroundStyle(isToday ? Theme.Palette.onPrimary : Theme.Palette.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(isToday ? Theme.Palette.textPrimary : .clear, in: .circle)
                        HStack(spacing: 2) {
                            if doneKinds.isEmpty {
                                Circle()
                                    .strokeBorder(planned == nil ? .clear : Theme.Palette.train.opacity(0.6), lineWidth: 1.5)
                                    .frame(width: 7, height: 7)
                            } else {
                                ForEach(Array(doneKinds.prefix(2).enumerated()), id: \.offset) { _, k in
                                    Circle().fill(k.color).frame(width: 7, height: 7)
                                }
                            }
                        }
                        .frame(height: 7)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(doneKinds.isEmpty ? (planned?.title ?? "Rest") : "\(doneKinds.count) done")")
                }
            }
        }
        .atlasCard()
    }
}

// MARK: - Load

private struct LoadCard: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let load = app.context.load
        let color: Color = load.status == "High" ? Theme.Palette.scoreLow : load.status == "Low" ? Theme.Palette.fuel : Theme.Palette.recovery
        HStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                MicroLabel("Training load · 7 days")
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                    Text("\(Int(load.acute7))").textStyle(.metricL).foregroundStyle(Theme.Palette.textPrimary)
                    Text(load.status).textStyle(.headline).foregroundStyle(color)
                }
                Text("Ratio \(String(format: "%.2f", load.ratio)) vs your 4-week average. Sweet spot is 0.8–1.3.")
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ScoreRing(progress: min(1, load.ratio / 1.6), color: color, diameter: 64) {
                Text(String(format: "%.1f", load.ratio)).textStyle(.metricS).foregroundStyle(Theme.Palette.textPrimary)
            }
        }
        .atlasCard()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rows

struct WorkoutRow: View {
    let workout: Workout
    @Environment(AppState.self) private var app

    var body: some View {
        let units = app.context.units
        HStack(spacing: Theme.Space.s) {
            IconDisk(symbol: workout.kind == .sport ? "figure.basketball" : workout.kind.symbol, color: workout.kind.color)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Space.xxs) {
                    Text(workout.title).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
                    if workout.prCount > 0 {
                        Text("PR").textStyle(.micro).foregroundStyle(Theme.Palette.onAccent)
                            .padding(.horizontal, Theme.Space.xxs + 2).padding(.vertical, 2)
                            .background(Theme.Palette.accentFill, in: .capsule)
                    }
                }
                Text(subtitle(units: units))
                    .textStyle(.footnote)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Space.xs)
            VStack(alignment: .trailing, spacing: 0) {
                Text(Fmt.relativeDay(workout.date)).textStyle(.footnote).foregroundStyle(Theme.Palette.textTertiary)
                Text("\(Int(workout.load))").textStyle(.metricS).foregroundStyle(Theme.Palette.textPrimary)
                Text("load").textStyle(.micro).foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(units: UnitSystem) -> String {
        var parts = [Fmt.duration(seconds: workout.durationSec)]
        if let d = workout.distanceM, d > 0 { parts.append(Fmt.distance(m: d, units: units)) }
        if let p = workout.paceSecPerKm { parts.append(Fmt.pace(secPerKm: p, units: units)) }
        if workout.kind == .strength, workout.volumeKg > 0 { parts.append("\(Fmt.weight(kg: workout.volumeKg, units: units)) volume") }
        if let hr = workout.avgHR { parts.append("\(hr) bpm") }
        return parts.joined(separator: " · ")
    }
}

extension WorkoutKind {
    var color: Color {
        switch self {
        case .strength, .plyometric: Theme.Palette.train
        case .cardio: Theme.Palette.recovery
        case .sport: Theme.Palette.fuel
        case .mobility: Theme.Palette.sleep
        }
    }
}

// MARK: - PR board

private struct PRBoard: View {
    let workouts: [Workout]
    @Environment(AppState.self) private var app

    private struct Best: Identifiable {
        let name: String
        let set: SetLog
        let date: Date
        var id: String { name }
    }

    private var bests: [Best] {
        var map: [String: Best] = [:]
        for w in workouts where w.kind == .strength {
            for ex in w.exercises {
                for s in ex.sets where s.weightKg > 0 && s.reps > 0 {
                    if let cur = map[ex.name], cur.set.e1RM >= s.e1RM { continue }
                    map[ex.name] = Best(name: ex.name, set: s, date: w.date)
                }
            }
        }
        return map.values.sorted { $0.set.e1RM > $1.set.e1RM }.prefix(5).map { $0 }
    }

    var body: some View {
        let list = bests
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(title: "Personal records")
                VStack(spacing: 0) {
                    ForEach(list) { b in
                        HStack(spacing: Theme.Space.s) {
                            Image(systemName: "trophy.fill").icon(Theme.Icon.small).foregroundStyle(Theme.Palette.accent)
                                .frame(width: Theme.Icon.large)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.name).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary).lineLimit(1)
                                Text("\(Fmt.weight(kg: b.set.weightKg, units: app.context.units)) × \(b.set.reps) · \(Fmt.relativeDay(b.date))")
                                    .textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(Fmt.weight(kg: b.set.e1RM, units: app.context.units)).textStyle(.metricS).foregroundStyle(Theme.Palette.textPrimary)
                                Text("est. 1RM").textStyle(.micro).foregroundStyle(Theme.Palette.textTertiary)
                            }
                        }
                        .padding(.vertical, Theme.Space.xs)
                        if b.id != list.last?.id { Hairline(leading: 34) }
                    }
                }
                .atlasCard()
            }
        }
    }
}

extension Calendar {
    static var mondayFirst: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }
}
