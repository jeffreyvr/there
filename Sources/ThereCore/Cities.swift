import Foundation

public struct ZoneChoice: Equatable, Sendable, Identifiable, Hashable {
    public var identifier: String
    public var city: String
    public var region: String
    public var code: String?

    public var id: String { identifier }

    public init(identifier: String, city: String, region: String, code: String?) {
        self.identifier = identifier
        self.city = city
        self.region = region
        self.code = code
    }
}

public enum Cities {
    public static let clientDefault = "Europe/Amsterdam"

    static let pinned: [ZoneChoice] = codesInOrder.compactMap { identifier, code in
        var choice = choice(for: identifier)
        choice.code = code
        return choice.identifier == identifier ? choice : nil
    }

    public static func choice(for identifier: String) -> ZoneChoice {
        let parts = identifier.split(separator: "/").map(String.init)
        let city = (parts.last ?? identifier).replacingOccurrences(of: "_", with: " ")
        let region = parts.count > 1 ? parts[0].replacingOccurrences(of: "_", with: " ") : ""
        return ZoneChoice(identifier: identifier, city: city, region: region, code: codes[identifier])
    }

    public static func code(for identifier: String) -> String {
        if let code = codes[identifier] { return code }
        if let zone = TimeZone(identifier: identifier),
           let abbreviation = zone.abbreviation(),
           abbreviation.allSatisfy(\.isLetter),
           abbreviation.count <= 4 {
            return abbreviation
        }
        return String(choice(for: identifier).city.prefix(3)).uppercased()
    }

    /// Empty query shows the trip list. A query searches every system time zone.
    public static func search(_ query: String) -> [ZoneChoice] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return pinned }

        let needle = trimmed.lowercased()
        return all.filter { zone in
            zone.city.lowercased().contains(needle)
                || zone.region.lowercased().contains(needle)
                || zone.identifier.lowercased().contains(needle)
                || zone.code?.lowercased().contains(needle) == true
        }
        .sorted { left, right in
            rank(left, needle: needle) < rank(right, needle: needle)
        }
        .prefix(40)
        .map { $0 }
    }

    private static func rank(_ zone: ZoneChoice, needle: String) -> Int {
        let city = zone.city.lowercased()
        if city == needle { return 0 }
        if city.hasPrefix(needle) { return 1 }
        if zone.code?.lowercased() == needle { return 2 }
        if pinnedIDs.contains(zone.identifier) { return 3 }
        return 4
    }

    private static let codesInOrder: [(String, String)] = [
        ("Europe/Amsterdam", "AMS"),
        ("Asia/Kathmandu", "KTM"),
        ("Asia/Hong_Kong", "HKG"),
        ("Asia/Bangkok", "BKK"),
        ("Asia/Singapore", "SIN"),
        ("Europe/London", "LON"),
        ("America/New_York", "NYC"),
        ("Asia/Tokyo", "TYO"),
        ("Asia/Dubai", "DXB"),
        ("Asia/Kolkata", "CCU"),
        ("America/Los_Angeles", "LAX"),
        ("Australia/Sydney", "SYD"),
    ]

    private static let codes: [String: String] = Dictionary(uniqueKeysWithValues: codesInOrder)

    private static let pinnedIDs = Set(codes.keys)

    private static let all: [ZoneChoice] = TimeZone.knownTimeZoneIdentifiers.map { choice(for: $0) }
}
