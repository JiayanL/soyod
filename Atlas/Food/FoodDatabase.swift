import Foundation

nonisolated struct FoodEntry: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var synonyms: [String] = []
    var category: String
    var serving: String          // "1 cup · 158 g"
    var grams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var emoji: String

    init(id: String, name: String, synonyms: [String], category: String,
         serving: String, grams: Double, kcal: Double, protein: Double,
         carbs: Double, fat: Double, emoji: String) {
        self.id = id; self.name = name; self.synonyms = synonyms; self.category = category
        self.serving = serving; self.grams = grams; self.kcal = kcal
        self.protein = protein; self.carbs = carbs; self.fat = fat; self.emoji = emoji
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        synonyms = try c.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        category = try c.decode(String.self, forKey: .category)
        serving = try c.decode(String.self, forKey: .serving)
        grams = try c.decode(Double.self, forKey: .grams)
        kcal = try c.decode(Double.self, forKey: .kcal)
        protein = try c.decode(Double.self, forKey: .protein)
        carbs = try c.decode(Double.self, forKey: .carbs)
        fat = try c.decode(Double.self, forKey: .fat)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "\u{1F37D}"
    }

    /// Converts this entry into a FoodItem for logging.
    func item(quantity: Double = 1, confidence: Double? = nil) -> FoodItem {
        FoodItem(foodId: id, name: name, servingDescription: serving,
                 quantity: quantity, kcalPerServing: kcal,
                 proteinPerServing: protein, carbsPerServing: carbs,
                 fatPerServing: fat, confidence: confidence, emoji: emoji)
    }
}

nonisolated final class FoodDatabase: Sendable {
    static let shared = FoodDatabase()

    let all: [FoodEntry]
    private let byId: [String: FoodEntry]

    private init() {
        let url = Bundle.main.url(forResource: "FoodDatabase", withExtension: "json")
        let decoded = url.flatMap {
            (try? JSONDecoder().decode([FoodEntry].self, from: Data(contentsOf: $0)))
        } ?? []
        all = decoded
        byId = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    func entry(id: String) -> FoodEntry? { byId[id] }

    /// Fuzzy search over name + synonyms.
    func search(_ query: String, limit: Int = 30) -> [FoodEntry] {
        let q = normalize(query)
        guard !q.isEmpty else { return Array(all.prefix(limit)) }
        var scored: [(Int, FoodEntry)] = []
        for e in all {
            let name = normalize(e.name)
            if name == q { scored.append((0, e)); continue }
            if e.synonyms.map(normalize).contains(q) { scored.append((1, e)); continue }
            if name.hasPrefix(q) { scored.append((2, e)); continue }
            if name.contains(q) { scored.append((3, e)); continue }
            if e.synonyms.map(normalize).contains(where: { $0.contains(q) || q.contains($0) }) {
                scored.append((4, e)); continue
            }
            // token overlap
            let tokens = Set(q.split(separator: " ").map(String.init))
            let nameTokens = Set(name.split(separator: " ").map(String.init))
            if !tokens.isDisjoint(with: nameTokens) { scored.append((5, e)) }
        }
        return scored.sorted { $0.0 < $1.0 }.prefix(limit).map(\.1)
    }

    /// Best single match for a free-text label ("grilled chicken", "rice").
    func bestMatch(for label: String) -> FoodEntry? {
        search(label, limit: 1).first
    }

    /// ~12 common staples for the Quick-add grid.
    var quickPicks: [FoodEntry] {
        let ids = ["chicken_breast", "white_rice", "egg", "banana",
                   "greek_yogurt", "oatmeal", "salmon", "avocado",
                   "protein_shake", "sweet_potato", "ground_beef_90", "broccoli"]
        return ids.compactMap { byId[$0] }
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
