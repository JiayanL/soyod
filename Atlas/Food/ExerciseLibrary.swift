import Foundation

struct ExerciseEntry: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var muscle: String          // Quads, Glutes, Chest, Back, …
    var equipment: String       // barbell, dumbbell, bodyweight, machine, cable, band, kettlebell
    var cue: String
    var isBodyweight: Bool
}

final class ExerciseLibrary: Sendable {
    static let shared = ExerciseLibrary()

    let all: [ExerciseEntry]
    private let byId: [String: ExerciseEntry]

    private init() {
        let url = Bundle.main.url(forResource: "ExerciseLibrary", withExtension: "json")
        let decoded = url.flatMap {
            (try? JSONDecoder().decode([ExerciseEntry].self, from: Data(contentsOf: $0)))
        } ?? []
        all = decoded
        byId = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    func entry(id: String) -> ExerciseEntry? { byId[id] }

    func search(_ query: String) -> [ExerciseEntry] {
        let q = query.lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(q) || $0.muscle.lowercased().contains(q)
        }
    }

    var muscles: [String] {
        var seen: [String] = []
        for e in all where !seen.contains(e.muscle) { seen.append(e.muscle) }
        return seen
    }

    func exercises(for muscle: String) -> [ExerciseEntry] {
        all.filter { $0.muscle == muscle }
    }
}
