import SwiftUI

/// Hevy-style strength logger with inline PREV, set checks and a sticky rest timer.
struct WorkoutLoggerView: View {
    let session: PlannedSession?

    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var exercises: [ExerciseLog]
    @State private var start = AppClock.now
    @State private var rest = RestTimer()
    @State private var showPicker = false
    @State private var confirmDiscard = false
    @State private var checks = 0

    init(session: PlannedSession?) {
        self.session = session
        _title = State(initialValue: session?.title ?? "Free workout")
        _exercises = State(initialValue: [])
    }

    private var units: UnitSystem { app.context.units }
    private var doneSets: Int { exercises.flatMap(\.sets).filter(\.done).count }
    private var volumeKg: Double { exercises.flatMap(\.sets).filter(\.done).reduce(0) { $0 + $1.weightKg * Double($1.reps) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    stats
                    ForEach($exercises) { $exercise in
                        ExerciseCard(
                            exercise: $exercise,
                            previous: app.previousSets(exerciseId: exercise.exerciseId),
                            units: units,
                            onCheck: { done in
                                if done {
                                    checks += 1
                                    rest.start(seconds: exercise.muscle == "Plyometric" ? 60 : 90)
                                }
                            },
                            onRemove: { exercises.removeAll { $0.id == exercise.id } }
                        )
                    }
                    if exercises.isEmpty {
                        EmptyStateView(symbol: "dumbbell", title: "Add your first exercise", message: "Pick from 85+ movements with coaching cues.", ctaTitle: "Add exercise") { showPicker = true }
                            .atlasCard()
                    } else {
                        Button {
                            showPicker = true
                        } label: {
                            Label("Add exercise", systemImage: "plus")
                        }
                        .buttonStyle(.atlasSecondary)
                        .accessibilityIdentifier("addExercise")
                    }
                }
                .gutter()
                .padding(.top, Theme.Space.s)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .atlasScreenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if doneSets > 0 { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish", action: finish)
                        .fontWeight(.semibold)
                        .disabled(doneSets == 0)
                        .accessibilityIdentifier("finishWorkout")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if rest.isRunning {
                    RestTimerPill(timer: rest)
                        .gutter()
                        .padding(.bottom, Theme.Space.xs)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Theme.Motion.standard, value: rest.isRunning)
            .sheet(isPresented: $showPicker) {
                ExercisePicker { entry in
                    let prev = app.previousSets(exerciseId: entry.id)
                    let sets = (0..<3).map { i in
                        SetLog(weightKg: prev[safe: i]?.weightKg ?? prev.last?.weightKg ?? 0, reps: prev[safe: i]?.reps ?? 8)
                    }
                    exercises.append(ExerciseLog(exerciseId: entry.id, name: entry.name, muscle: entry.muscle, sets: sets))
                }
                .presentationDetents([.large])
                .presentationCornerRadius(Theme.Radius.sheet)
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: checks)
            .onAppear(perform: load)
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            TimelineView(.periodic(from: start, by: 1)) { _ in
                stat("Duration", value: clock(Int(AppClock.now.timeIntervalSince(start))))
            }
            stat("Volume", value: Fmt.weight(kg: volumeKg, units: units))
            stat("Sets", value: "\(doneSets)")
        }
        .atlasCard()
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            MicroLabel(label)
            Text(value)
                .textStyle(.metricM)
                .foregroundStyle(Theme.Palette.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clock(_ s: Int) -> String {
        s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func load() {
        guard exercises.isEmpty, let session else { return }
        exercises = session.blocks.flatMap(\.exercises).map { planned in
            let entry = ExerciseLibrary.shared.entry(id: planned.exerciseId)
            let prev = app.previousSets(exerciseId: planned.exerciseId)
            let reps = Int(planned.reps.prefix { $0.isNumber }) ?? 8
            let sets = (0..<max(1, planned.sets)).map { i in
                SetLog(weightKg: prev[safe: i]?.weightKg ?? planned.targetWeightKg ?? prev.last?.weightKg ?? 0, reps: prev[safe: i]?.reps ?? reps)
            }
            return ExerciseLog(exerciseId: planned.exerciseId, name: planned.name, muscle: entry?.muscle ?? "Full body", sets: sets)
        }
    }

    private func finish() {
        rest.stop()
        let cleaned = exercises.compactMap { ex -> ExerciseLog? in
            var e = ex
            e.sets = ex.sets.filter(\.done)
            return e.sets.isEmpty ? nil : e
        }
        let duration = max(60, Int(AppClock.now.timeIntervalSince(start)))
        let kind: WorkoutKind = session?.kind ?? .strength
        let draft = WorkoutDraft(kind: kind == .plyometric ? .strength : kind, title: title, start: start, durationSec: max(duration, (session?.durationMin ?? 0) * 60 / 2), exercises: cleaned, rpe: 7)
        let result = app.saveWorkout(draft)
        router.sheet = .workoutSummary(result)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Exercise card

private struct ExerciseCard: View {
    @Binding var exercise: ExerciseLog
    let previous: [SetLog]
    let units: UnitSystem
    let onCheck: (Bool) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                    Text(ExerciseLibrary.shared.entry(id: exercise.exerciseId)?.cue ?? exercise.muscle)
                        .textStyle(.footnote)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Menu {
                    Button(role: .destructive, action: onRemove) { Label("Remove exercise", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .icon(Theme.Icon.regular)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .frame(width: Theme.Size.minTap, height: Theme.Size.minTap)
                }
                .accessibilityLabel("Exercise options")
            }
            HStack(spacing: Theme.Space.xs) {
                Text("SET").frame(width: 28, alignment: .leading)
                Text("PREV").frame(maxWidth: .infinity, alignment: .leading)
                Text(ExerciseLibrary.shared.entry(id: exercise.exerciseId)?.isBodyweight == true ? "LOAD" : UnitConvert.weightUnit(units).uppercased()).frame(width: 64)
                Text("REPS").frame(width: 48)
                Image(systemName: "checkmark").frame(width: 36)
            }
            .textStyle(.micro)
            .foregroundStyle(Theme.Palette.textTertiary)
            ForEach(Array($exercise.sets.enumerated()), id: \.element.id) { index, $set in
                SetRow(index: index, set: $set, previous: previous[safe: index], units: units, isBodyweight: ExerciseLibrary.shared.entry(id: exercise.exerciseId)?.isBodyweight ?? false, onCheck: onCheck)
            }
            Button {
                let last = exercise.sets.last
                withAnimation(Theme.Motion.snappy) {
                    exercise.sets.append(SetLog(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 8))
                }
            } label: {
                Label("Add set", systemImage: "plus")
                    .textStyle(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.small, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .atlasCard()
    }
}

private struct SetRow: View {
    let index: Int
    @Binding var set: SetLog
    let previous: SetLog?
    let units: UnitSystem
    var isBodyweight = false
    let onCheck: (Bool) -> Void

    private var showsBodyweight: Bool { isBodyweight && set.weightKg == 0 }

    private var weight: Binding<Double> {
        Binding(
            get: { (UnitConvert.weightDisplay(kg: set.weightKg, units: units) * 2).rounded() / 2 },
            set: { set.weightKg = UnitConvert.weightCanonical($0, units: units) }
        )
    }

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Text("\(index + 1)")
                .textStyle(.metricS)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 28, alignment: .leading)
            Text(previous.map { "\(UnitConvert.number(UnitConvert.weightDisplay(kg: $0.weightKg, units: units), decimals: 0)) × \($0.reps)" } ?? "—")
                .textStyle(.footnote)
                .foregroundStyle(Theme.Palette.textTertiary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsBodyweight {
                Text("BW")
                    .textStyle(.metricS)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(width: 64, height: 36)
                    .accessibilityLabel("Set \(index + 1) bodyweight")
            } else {
                TextField("0", value: weight, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .textStyle(.metricS)
                    .frame(width: 64, height: 36)
                    .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.tiny, style: .continuous))
                    .accessibilityLabel("Set \(index + 1) weight")
            }
            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textStyle(.metricS)
                .frame(width: 48, height: 36)
                .background(Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.tiny, style: .continuous))
                .accessibilityLabel("Set \(index + 1) reps")
            Button {
                withAnimation(Theme.Motion.snappy) { set.done.toggle() }
                onCheck(set.done)
                hideKeyboard()
            } label: {
                Image(systemName: "checkmark")
                    .icon(Theme.Icon.small, weight: .bold)
                    .foregroundStyle(set.done ? Theme.Palette.onAccent : Theme.Palette.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(set.done ? Theme.Palette.accentFill : Theme.Palette.fill, in: .rect(cornerRadius: Theme.Radius.tiny, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.done ? "Set \(index + 1) done" : "Complete set \(index + 1)")
            .accessibilityIdentifier("setCheck")
        }
        .padding(.vertical, 2)
        .background(set.done ? Theme.Palette.accentFill.opacity(0.08) : .clear, in: .rect(cornerRadius: Theme.Radius.tiny))
    }
}

// MARK: - Rest timer

@Observable @MainActor
final class RestTimer {
    var endsAt: Date?
    var total: Int = 90
    var isRunning: Bool { endsAt != nil }
    private var task: Task<Void, Never>?

    func start(seconds: Int) {
        total = seconds
        endsAt = Date().addingTimeInterval(TimeInterval(seconds))
        schedule()
    }

    func add(_ seconds: Int) {
        guard let e = endsAt else { return }
        let next = e.addingTimeInterval(TimeInterval(seconds))
        if next <= Date() { stop(); return }
        total = max(total + seconds, 1)
        endsAt = next
        schedule()
    }

    func stop() {
        task?.cancel()
        endsAt = nil
    }

    private func schedule() {
        task?.cancel()
        guard let endsAt else { return }
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, endsAt.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.endsAt = nil
        }
    }
}

private struct RestTimerPill: View {
    let timer: RestTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            let left = max(0, Int((timer.endsAt ?? ctx.date).timeIntervalSince(ctx.date).rounded(.up)))
            HStack(spacing: Theme.Space.s) {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    HStack(spacing: Theme.Space.xxs) {
                        Image(systemName: "timer").icon(Theme.Icon.small)
                        Text("Rest").textStyle(.micro)
                    }
                    .foregroundStyle(Theme.Palette.textSecondary)
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .textStyle(.metricM)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                }
                ProgressTrack(fraction: Double(left) / Double(max(1, timer.total)), color: Theme.Palette.accentFill, height: 6)
                Button("−15") { timer.add(-15) }.buttonStyle(.atlasChip)
                Button("+15") { timer.add(15) }.buttonStyle(.atlasChip)
                Button { timer.stop() } label: {
                    Image(systemName: "forward.end.fill").icon(Theme.Icon.small)
                }
                .buttonStyle(.atlasChip)
                .accessibilityLabel("Skip rest")
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, Theme.Space.s)
            .modifier(GlassCapsule())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("restTimer")
        }
    }
}

// MARK: - Exercise picker

struct ExercisePicker: View {
    let onPick: (ExerciseEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var muscle: String?

    var body: some View {
        NavigationStack {
            let all = ExerciseLibrary.shared.search(query)
            let muscles = Array(Set(ExerciseLibrary.shared.all.map(\.muscle))).sorted()
            let list = all.filter { muscle == nil || $0.muscle == muscle }
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Space.xs) {
                            Button("All") { muscle = nil }.buttonStyle(ChipButtonStyle(selected: muscle == nil))
                            ForEach(muscles, id: \.self) { m in
                                Button(m) { muscle = m }.buttonStyle(ChipButtonStyle(selected: muscle == m))
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    ForEach(list) { entry in
                        Button {
                            onPick(entry)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name).textStyle(.headline).foregroundStyle(Theme.Palette.textPrimary)
                                Text("\(entry.muscle) · \(entry.equipment)").textStyle(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        .listRowBackground(Theme.Palette.surface)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.bg)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
