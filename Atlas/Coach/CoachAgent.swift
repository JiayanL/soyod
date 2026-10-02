import Foundation

nonisolated struct ChatTurn: Codable, Hashable, Sendable {
    var role: MessageRole
    var text: String
}

nonisolated struct MemoryDraft: Codable, Hashable, Sendable {
    var kind: MemoryKind
    var text: String
    var dueDate: Date?
}

nonisolated enum CoachLog: Sendable {
    case meal(title: String, mealType: MealType, items: [FoodItem])
    case workout(kind: WorkoutKind, title: String, durationMin: Int,
                 distanceM: Double?, rpe: Double?, sport: String?)
}

nonisolated struct CoachReply: Sendable {
    var text: String
    var actions: [CoachAction] = []
    var memoryWrites: [MemoryDraft] = []
    var logs: [CoachLog] = []
}

nonisolated struct CoachEngineStatus: Sendable {
    var name: String          // "Apple Intelligence" / "Atlas on-device" / "Remote · <model>"
    var detail: String
}

protocol CoachAgent {
    var displayName: String { get }
    func respond(to text: String, history: [ChatTurn], context: CoachContext) async throws -> CoachReply
}
