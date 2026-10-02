import Foundation

/// Extracts long-term memories from chat text: explicit "remember …" plus
/// auto-detection of facts/preferences ("my knee …", "I'm vegetarian").
nonisolated enum MemoryExtractor {

    static func extract(from text: String, now: Date = AppClock.now) -> [MemoryDraft] {
        var out: [MemoryDraft] = []
        let lower = text.lowercased()

        // Explicit "remember (that) …"
        if let range = lower.range(of: #"remember\s+(that\s+|to\s+)?"#, options: .regularExpression) {
            let start = text.index(text.startIndex, offsetBy: range.upperBound.utf16Offset(in: lower))
            let body = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if !body.isEmpty {
                // Due date hints.
                var due: Date?
                if lower.contains("tomorrow") {
                    due = Calendar.current.date(byAdding: .day, value: 1, to: now)
                } else if lower.contains("tonight") {
                    due = now
                }
                out.append(MemoryDraft(kind: .task, text: body.prefix(1).uppercased() + body.dropFirst(), dueDate: due))
            }
        }

        // Body / pain facts: "my knee …", "my shoulder hurts"
        if let m = lower.range(of: #"my (knee|shoulder|back|ankle|hip|wrist|elbow|neck)[^.]*"#,
                               options: .regularExpression) {
            let frag = String(text[text.index(text.startIndex, offsetBy: m.lowerBound.utf16Offset(in: lower))...])
                .components(separatedBy: ".").first ?? ""
            if !frag.isEmpty, !frag.lowercased().hasPrefix("remember") {
                out.append(MemoryDraft(kind: .fact, text: frag.prefix(1).uppercased() + frag.dropFirst(), dueDate: nil))
            }
        }

        // Diet / identity: "I'm vegetarian", "I am vegan", "I don't eat …"
        if lower.range(of: #"i('m| am) (a\s+)?(vegetarian|vegan|pescatarian|keto|lactose|gluten[- ]free)"#,
                       options: .regularExpression) != nil {
            if let m = lower.range(of: #"i('m| am| don't eat| do not eat)[^.]*"#, options: .regularExpression) {
                let frag = String(text[text.index(text.startIndex, offsetBy: m.lowerBound.utf16Offset(in: lower))...])
                out.append(MemoryDraft(kind: .preference, text: frag.prefix(1).uppercased() + frag.dropFirst(), dueDate: nil))
            }
        }

        // People: "my girlfriend/wife/partner is …"
        if let m = lower.range(of: #"(my )?(girlfriend|wife|partner|boyfriend|husband|fiancee?)\s+(is|has|can't|cannot|doesn't)[^.]*"#,
                               options: .regularExpression) {
            let frag = String(text[text.index(text.startIndex, offsetBy: m.lowerBound.utf16Offset(in: lower))...])
            if !frag.isEmpty {
                out.append(MemoryDraft(kind: .fact, text: frag.prefix(1).uppercased() + frag.dropFirst(), dueDate: nil))
            }
        }

        // Recurring schedule: "every Monday/Thursday …"
        if let m = lower.range(of: #"every (monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|morning|night)[^.]*"#,
                               options: .regularExpression) {
            let frag = String(text[text.index(text.startIndex, offsetBy: m.lowerBound.utf16Offset(in: lower))...])
            out.append(MemoryDraft(kind: .fact, text: frag.prefix(1).uppercased() + frag.dropFirst(), dueDate: nil))
        }

        // Travel: "I travel …", "I fly to …"
        if let m = lower.range(of: #"i (travel|fly to|commute)[^.]*"#, options: .regularExpression) {
            let frag = String(text[text.index(text.startIndex, offsetBy: m.lowerBound.utf16Offset(in: lower))...])
            out.append(MemoryDraft(kind: .fact, text: frag.prefix(1).uppercased() + frag.dropFirst(), dueDate: nil))
        }

        // Allergies: "allergic to …"
        if let m = lower.range(of: #"allergic to [a-z ]+"#, options: .regularExpression) {
            let frag = String(text[text.index(text.startIndex, offsetBy: m.lowerBound.utf16Offset(in: lower))...])
            out.append(MemoryDraft(kind: .fact, text: "Allergic to " + frag.replacingOccurrences(of: "allergic to ", with: "", options: .caseInsensitive).prefix(1).uppercased() + frag.dropFirst(12), dueDate: nil))
        }

        return out
    }
}
