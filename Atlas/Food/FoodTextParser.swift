import Foundation

/// Parses free-text food descriptions into FoodItems.
/// "2 eggs, toast with avocado, black coffee", "1 cup rice", "200g chicken breast",
/// "a banana", "half an avocado".
nonisolated enum FoodTextParser {

    static func parse(_ text: String) -> [FoodItem] {
        // Split on commas / " and " boundaries ("with" stays — dropped as trailing words).
        let cleaned = text.lowercased()
            .replacingOccurrences(of: " and a ", with: ", ")
            .replacingOccurrences(of: " and some ", with: ", ")
            .replacingOccurrences(of: " and ", with: ", ")
        let pieces = cleaned.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return pieces.compactMap { parsePiece($0) }
    }

    private static func parsePiece(_ piece: String) -> FoodItem? {
        var p = piece
        var quantity: Double = 1
        var gramAmount: Double?

        // Leading "a/an/one/some".
        p = p.replacingOccurrences(of: #"^(a|an|one|some)\s+"#, with: "1 ",
                                   options: .regularExpression)
        // "half (of) (a|an)" → 0.5.
        p = p.replacingOccurrences(of: #"^(half|1/2)\s+(of\s+)?(a\s+|an\s+)?"#, with: "0.5 ",
                                   options: .regularExpression)
        // Gram amount first ("200g chicken", "chicken 200 g") so "200" isn't
        // eaten as a serving count.
        if let m = p.range(of: #"^(\d+(?:\.\d+)?)\s*(g|grams?)\s+"#, options: .regularExpression) {
            gramAmount = Double(p[m].components(separatedBy: CharacterSet.letters).first ?? "")
            p = String(p[m.upperBound...])
        } else if let m = p.range(of: #"^(\d+(?:\.\d+)?)\s*(g|grams?)$"#, options: .regularExpression) {
            gramAmount = Double(p[m].components(separatedBy: CharacterSet.letters).first ?? "")
            p = ""
        }
        // Leading number ("2 eggs").
        if gramAmount == nil,
           let m = p.range(of: #"^(\d+(?:\.\d+)?)\s*"#, options: .regularExpression) {
            quantity = Double(p[m].trimmingCharacters(in: .whitespaces)) ?? 1
            p = String(p[m.upperBound...])
        }
        // Volume units hint the serving match ("1 cup rice", "2 scoops whey").
        var unitHint: String?
        if let m = p.range(of: #"^(cup|cups|tbsp|tablespoons?|tsp|teaspoons?|scoop|scoops?|slice|slices|piece|pieces|bowl|bowls|can|cans|bottle|bottles)\s+"#,
                           options: .regularExpression) {
            unitHint = String(p[m]).trimmingCharacters(in: .whitespaces)
            p = String(p[m.upperBound...])
        }
        p = p.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return nil }

        // Try the whole phrase, then drop trailing words ("toast with avocado" → "toast").
        var entry = FoodDatabase.shared.bestMatch(for: p)
        while entry == nil, let lastSpace = p.lastIndex(of: " ") {
            p = String(p[..<lastSpace])
            entry = FoodDatabase.shared.bestMatch(for: p)
        }
        guard let entry else { return nil }

        var item = entry.item(quantity: quantity)
        if let grams = gramAmount, entry.grams > 0 {
            item.quantity = grams / entry.grams
            item.servingDescription = "\(Int(grams)) g"
        } else if let unit = unitHint {
            let singular = unit.replacingOccurrences(of: "s$", with: "", options: .regularExpression)
            item.servingDescription = "\(quantity == 1 ? "1" : trimmed(quantity)) \(singular) · \(Int(entry.grams)) g"
        }
        return item
    }

    private static func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
