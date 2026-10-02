import Foundation

/// Pure URL construction for agent actions (unit-tested).
enum ActionURLBuilder {

    /// OpenTable search: covers + ISO datetime + term.
    static func openTable(restaurant: String, partySize: Int, date: Date) -> URL? {
        var c = URLComponents(string: "https://www.opentable.com/s")
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        c?.queryItems = [
            URLQueryItem(name: "covers", value: "\(partySize)"),
            URLQueryItem(name: "dateTime", value: iso.string(from: date)),
            URLQueryItem(name: "term", value: restaurant),
        ]
        return c?.url
    }

    static func resy(restaurant: String, partySize: Int, date: Date, city: String = "new-york") -> URL? {
        var c = URLComponents(string: "https://resy.com/cities/\(city.slugified)")
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        c?.queryItems = [
            URLQueryItem(name: "date", value: f.string(from: date)),
            URLQueryItem(name: "seats", value: "\(partySize)"),
            URLQueryItem(name: "query", value: restaurant),
        ]
        return c?.url
    }

    static func doorDash(query: String) -> URL? {
        var c = URLComponents(string: "https://www.doordash.com/search/store/\(query.slugified)/")
        return c?.url
    }

    static func uberEats(query: String) -> URL? {
        var c = URLComponents(string: "https://www.ubereats.com/search")
        c?.queryItems = [URLQueryItem(name: "q", value: query)]
        return c?.url
    }
}

extension String {
    /// "Nobu Malibu" -> "nobu-malibu"
    var slugified: String {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
