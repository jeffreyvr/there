import Foundation

/// A calendar date with no clock and no zone.
/// "15 July" stays 15 July when it is applied inside Amsterdam or Kathmandu.
public struct CivilDay: Equatable, Sendable, Hashable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func today(in zone: TimeZone, now: Date = .now) -> CivilDay {
        var calendar = gregorian
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return CivilDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public func adding(days: Int) -> CivilDay {
        let calendar = Self.gregorian
        guard let date = calendar.date(from: dateComponents),
              let shifted = calendar.date(byAdding: .day, value: days, to: date)
        else {
            return self
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
        return CivilDay(year: parts.year ?? year, month: parts.month ?? month, day: parts.day ?? day)
    }

    var dateComponents: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }

    /// Stable calendar used only to move civil dates. Zone is UTC so the Y-M-D cannot drift.
    static var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }
}
