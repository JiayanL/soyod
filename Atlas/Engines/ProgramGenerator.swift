import Foundation

nonisolated enum ProgramGenerator {

    /// Weekly split of PlannedSessions for a goal. Rest days are absent.
    /// Weekday: 1 = Monday … 7 = Sunday.
    static func weeklySplit(goal: GoalKind, daysPerWeek: Int,
                            equipment: Equipment, experience: Experience) -> [PlannedSession] {
        switch goal {
        case .vertical: return verticalSplit(days: daysPerWeek, equipment: equipment, experience: experience)
        case .glutes: return glutesSplit(days: daysPerWeek, equipment: equipment, experience: experience)
        case .waist, .fatLoss: return fatLossSplit(days: daysPerWeek, equipment: equipment, experience: experience, waist: goal == .waist)
        case .muscle: return muscleSplit(days: daysPerWeek, equipment: equipment, experience: experience)
        case .strength: return strengthSplit(days: daysPerWeek, equipment: equipment, experience: experience)
        case .run: return runSplit(days: daysPerWeek, experience: experience)
        case .custom: return muscleSplit(days: daysPerWeek, equipment: equipment, experience: experience)
        }
    }

    /// The session scheduled on `date`, if any.
    static func session(on date: Date, split: [PlannedSession],
                        calendar: Calendar = .current) -> PlannedSession? {
        let wd = calendar.component(.weekday, from: date) // 1=Sun … 7=Sat
        let monday1 = wd == 1 ? 7 : wd - 1
        return split.first { $0.weekday == monday1 }
    }

    // MARK: - Builders

    private static func ex(_ id: String, _ sets: Int, _ reps: String, _ cue: String, kg: Double? = nil) -> PlannedExercise {
        PlannedExercise(exerciseId: id, name: ExerciseLibrary.shared.entry(id: id)?.name ?? id,
                        sets: sets, reps: reps, cue: cue, targetWeightKg: kg)
    }

    private static func block(_ title: String, _ exercises: [PlannedExercise]) -> PlannedBlock {
        PlannedBlock(title: title, exercises: exercises)
    }

    private static func session(_ weekday: Int, _ title: String, _ focus: String,
                                _ kind: WorkoutKind, _ min: Int, _ blocks: [PlannedBlock]) -> PlannedSession {
        PlannedSession(weekday: weekday, title: title, focus: focus, kind: kind,
                       durationMin: min, blocks: blocks)
    }

    // MARK: - Vertical (plyo + lower strength)

    private static func verticalSplit(days: Int, equipment: Equipment, experience: Experience) -> [PlannedSession] {
        let home = equipment != .gym
        let plyoSets = experience == .beginner ? 3 : 4
        var out: [PlannedSession] = []

        out.append(session(1, "Lower power", "Plyometrics + strength", .plyometric, 70, [
            block("Plyometrics", [
                ex("pogo_hops", plyoSets, "10", "Stiff ankles, minimal ground time"),
                ex("depth_jumps", 3, "5", "Step off, land soft, jump immediately"),
                ex("box_jumps", 4, "5", "Full hip extension, step down — don't jump down"),
            ]),
            block("Strength", [
                ex("trap_bar_deadlift", 4, "5", "Push the floor away, brace hard"),
                ex("bulgarian_split_squat", 3, "8", "Long stride, torso tall"),
            ]),
            block("Core", [
                ex("pallof_press", 3, "10", "Resist the rotation, ribs down"),
            ]),
        ]))

        out.append(session(2, "Upper strength", "Press + pull", .strength, 55, [
            block("Strength", [
                ex("bench_press", 4, "6", "Legs drive, touch lower chest"),
                ex("pull_ups", 4, "6–8", "Full hang to chin over bar"),
                ex("overhead_press", 3, "8", "Glutes tight, no lean back"),
                ex("barbell_row", 3, "10", "Pull to lower ribs, no bounce"),
            ]),
            block("Arms", [
                ex("incline_db_curl", 2, "12", "Stretch at the bottom"),
            ]),
        ]))

        out.append(session(4, "Reactive + speed", "Elasticity + sprint work", .plyometric, 55, [
            block("Plyometrics", [
                ex("ankle_hops", 4, "15", "Quick off the floor, quiet landings"),
                ex("hurdle_hops", 4, "6", "Strike and react — minimal contact"),
                ex("single_leg_bounds", 3, "6/side", "Stick each landing one beat"),
            ]),
            block("Speed", [
                ex("hill_sprints", 6, "15 m", "Full recovery between reps"),
            ]),
            block("Mobility", [
                ex("couch_stretch", 2, "60s/side", "Posterior tilt, squeeze glute"),
            ]),
        ]))

        out.append(session(6, "Lower strength", "Heavy lower + jump-specific", .strength, 70, [
            block("Strength", [
                ex("back_squat", 4, "5", home ? "Controlled tempo, chest up" : "Brace, drive knees out"),
                ex("hip_thrust", 3, "8", "Chin tucked, lockout squeeze 1s"),
                ex("nordic_curl", 3, "5", "Slow eccentric — fight the way down"),
            ]),
            block("Calves + tibialis", [
                ex("standing_calf_raise", 4, "10", "Pause at the top"),
                ex("tibialis_raise", 3, "15", "Full range, toes up hard"),
            ]),
        ]))

        if days >= 5 {
            out.append(session(3, "Mobility + Zone 2", "Recovery day", .mobility, 35, [
                block("Zone 2", [ex("incline_walk", 1, "20 min", "Conversational pace")]),
                block("Mobility", [
                    ex("worlds_greatest_stretch", 2, "5/side", "Breathe into the hip"),
                    ex("hip_flexor_stretch", 2, "45s/side", "Glute squeezed"),
                ]),
            ]))
        }
        return scaleToDays(out, days)
    }

    // MARK: - Glutes

    private static func glutesSplit(days: Int, equipment: Equipment, experience: Experience) -> [PlannedSession] {
        var out: [PlannedSession] = []
        out.append(session(1, "Glute strength", "Hip thrust emphasis", .strength, 65, [
            block("Strength", [
                ex("hip_thrust", 4, "8", "Full lockout, 1s squeeze"),
                ex("romanian_deadlift", 3, "8", "Push hips back, soft knees"),
                ex("bulgarian_split_squat", 3, "10/side", "Lean slightly forward"),
            ]),
            block("Accessory", [
                ex("cable_kickback", 3, "12/side", "Squeeze at full extension"),
            ]),
        ]))
        out.append(session(3, "Upper + core", "Balanced volume", .strength, 50, [
            block("Strength", [
                ex("bench_press", 3, "8", "Controlled tempo"),
                ex("pull_ups", 3, "6–8", "Full range"),
                ex("overhead_press", 3, "10", "No lean back"),
            ]),
            block("Core", [ex("plank", 3, "45s", "Ribs down, glutes on")]),
        ]))
        out.append(session(5, "Glute volume", "Hypertrophy day", .strength, 60, [
            block("Strength", [
                ex("hip_thrust", 4, "10–12", "Chase the burn, lockout pause"),
                ex("sumo_deadlift", 3, "8", "Knees out, chest tall"),
                ex("walking_lunges", 3, "12/side", "Long steps, torso upright"),
            ]),
            block("Accessory", [
                ex("abductor_machine", 3, "15", "Control the return"),
            ]),
        ]))
        if days >= 4 {
            out.append(session(6, "Glute pump + Zone 2", "Metabolic + cardio", .strength, 40, [
                block("Pump", [
                    ex("glute_bridge", 3, "15", "2s hold at top"),
                    ex("band_sidesteps", 3, "20 steps", "Knees out the whole way"),
                ]),
                block("Cardio", [ex("incline_walk", 1, "20 min", "Zone 2")]),
            ]))
        }
        return scaleToDays(out, days)
    }

    // MARK: - Fat loss / waist

    private static func fatLossSplit(days: Int, equipment: Equipment, experience: Experience, waist: Bool) -> [PlannedSession] {
        var out: [PlannedSession] = []
        out.append(session(1, "Full body A", "Strength + conditioning", .strength, 60, [
            block("Strength", [
                ex("goblet_squat", 4, "10", "Elbows inside knees"),
                ex("bench_press", 3, "10", "Control the negative"),
                ex("barbell_row", 3, "10", "Squeeze shoulder blades"),
            ]),
            block("Conditioning", [ex("kettlebell_swings", 4, "15", "Snap the hips")]),
        ]))
        out.append(session(3, "Zone 2 + core", "Aerobic base", .cardio, 45, [
            block("Cardio", [ex("incline_walk", 1, "30 min", "Zone 2 — nasal breathing")]),
            block("Core", [
                ex("dead_bug", 3, "10/side", "Low back stays down"),
                ex("side_plank", 3, "30s/side", "Stack hips"),
            ]),
        ]))
        out.append(session(5, "Full body B", "Strength + steps", .strength, 60, [
            block("Strength", [
                ex("romanian_deadlift", 4, "10", "Hips back, hamstrings loaded"),
                ex("overhead_press", 3, "10", "Ribs down"),
                ex("lat_pulldown", 3, "12", "Drive elbows to hips"),
            ]),
            block("Core", [ex("plank", 3, "45s", "Squeeze everything")]),
        ]))
        if days >= 4 {
            out.append(session(6, "Long Zone 2", "Weekend cardio", .cardio, 50, [
                block("Cardio", [ex("incline_walk", 1, "40 min", "Easy pace, incline ok")]),
            ]))
        }
        return scaleToDays(out, days)
    }

    // MARK: - Muscle

    private static func muscleSplit(days: Int, equipment: Equipment, experience: Experience) -> [PlannedSession] {
        var out: [PlannedSession] = []
        out.append(session(1, "Push", "Chest + shoulders + triceps", .strength, 60, [
            block("Strength", [
                ex("bench_press", 4, "8", "Pause on chest"),
                ex("overhead_press", 3, "8", "Squeeze glutes"),
                ex("incline_db_press", 3, "10", "Full stretch"),
            ]),
            block("Accessory", [
                ex("lateral_raise", 3, "15", "Lead with elbows"),
                ex("rope_pushdown", 3, "12", "Full extension"),
            ]),
        ]))
        out.append(session(2, "Pull", "Back + biceps", .strength, 60, [
            block("Strength", [
                ex("pull_ups", 4, "6–8", "Chest to bar"),
                ex("barbell_row", 4, "10", "No torso bounce"),
            ]),
            block("Accessory", [
                ex("face_pull", 3, "15", "External rotate at the end"),
                ex("incline_db_curl", 3, "12", "Slow negatives"),
            ]),
        ]))
        out.append(session(4, "Legs", "Quads + posterior", .strength, 65, [
            block("Strength", [
                ex("back_squat", 4, "8", "Depth below parallel"),
                ex("romanian_deadlift", 3, "10", "Feel the hamstrings"),
                ex("leg_press", 3, "12", "Full range, no knee lock"),
            ]),
            block("Accessory", [ex("standing_calf_raise", 4, "12", "Pause top and bottom")]),
        ]))
        if days >= 4 {
            out.append(session(6, "Upper pump", "Second upper day", .strength, 50, [
                block("Strength", [
                    ex("incline_db_press", 3, "10", "Controlled"),
                    ex("lat_pulldown", 3, "12", "Squeeze at chest"),
                    ex("lateral_raise", 3, "15", "Light and strict"),
                    ex("rope_pushdown", 3, "15", "Burn out"),
                ]),
            ]))
        }
        return scaleToDays(out, days)
    }

    // MARK: - Strength (5/3/1-flavored)

    private static func strengthSplit(days: Int, equipment: Equipment, experience: Experience) -> [PlannedSession] {
        var out: [PlannedSession] = []
        out.append(session(1, "Squat day", "Main lift + volume", .strength, 70, [
            block("Main lift", [ex("back_squat", 5, "5", "Brace hard, knees out")]),
            block("Volume", [
                ex("leg_press", 3, "10", "Controlled"),
                ex("romanian_deadlift", 3, "8", "Hamstring stretch"),
            ]),
        ]))
        out.append(session(2, "Bench day", "Press + pull volume", .strength, 60, [
            block("Main lift", [ex("bench_press", 5, "5", "Leg drive, tight setup")]),
            block("Volume", [
                ex("barbell_row", 4, "8", "Explosive pull"),
                ex("incline_db_press", 3, "10", "Stretch at bottom"),
            ]),
        ]))
        out.append(session(4, "Deadlift day", "Posterior chain", .strength, 70, [
            block("Main lift", [ex("trap_bar_deadlift", 5, "5", "Push the floor away")]),
            block("Volume", [
                ex("pull_ups", 4, "6", "Full range"),
                ex("hip_thrust", 3, "10", "Lockout squeeze"),
            ]),
        ]))
        if days >= 4 {
            out.append(session(6, "Press + arms", "OHP + accessories", .strength, 55, [
                block("Main lift", [ex("overhead_press", 5, "5", "No leg kick")]),
                block("Accessory", [
                    ex("lat_pulldown", 3, "10", "Elbows to ribs"),
                    ex("incline_db_curl", 3, "12", "Strict"),
                    ex("rope_pushdown", 3, "12", "Full extension"),
                ]),
            ]))
        }
        return scaleToDays(out, days)
    }

    // MARK: - Run

    private static func runSplit(days: Int, experience: Experience) -> [PlannedSession] {
        var out: [PlannedSession] = []
        out.append(session(2, "Easy run", "Aerobic base", .cardio, 40, [
            block("Run", [ex("zone2_run", 1, "35 min", "Conversational pace")]),
        ]))
        out.append(session(4, "Intervals", "VO2 work", .cardio, 45, [
            block("Warm-up", [ex("zone2_run", 1, "10 min", "Easy jog")]),
            block("Main set", [ex("interval_400", 6, "400 m", "5K pace, 90s jog rest")]),
            block("Cool-down", [ex("zone2_run", 1, "8 min", "Easy jog")]),
        ]))
        out.append(session(6, "Long run", "Endurance", .cardio, 60, [
            block("Run", [ex("zone2_run", 1, "50 min", "Stay in Zone 2")]),
        ]))
        if days >= 4 {
            out.append(session(1, "Strength for runners", "Durability", .strength, 40, [
                block("Strength", [
                    ex("goblet_squat", 3, "10", "Controlled"),
                    ex("single_leg_rdl", 3, "8/side", "Balance first"),
                    ex("standing_calf_raise", 3, "15", "Full range"),
                    ex("side_plank", 3, "30s/side", "Stack hips"),
                ]),
            ]))
        }
        return scaleToDays(out, days)
    }

    // MARK: - Helpers

    /// Trim/extend a template to exactly `days` sessions, keeping weekday order.
    private static func scaleToDays(_ sessions: [PlannedSession], _ days: Int) -> [PlannedSession] {
        if sessions.count == days { return sessions }
        if sessions.count > days {
            return Array(sessions.sorted { $0.weekday < $1.weekday }
                .sorted { abs($0.weekday - 4) < abs($1.weekday - 4) }
                .suffix(days)
                .sorted { $0.weekday < $1.weekday })
        }
        return sessions
    }
}
