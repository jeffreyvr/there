import Foundation

public enum InputSide: String, Equatable, Sendable {
    case theirs
    case mine
}

public enum SideState: Equatable, Sendable {
    case inHours
    case early
    case late
}

public struct Verdict: Equatable, Sendable {
    public enum Tone: Equatable, Sendable {
        case good
        case mixed
        case bad
    }

    public var tone: Tone
    public var sentence: String

    public init(tone: Tone, sentence: String) {
        self.tone = tone
        self.sentence = sentence
    }
}

public enum TimeMatch: Equatable, Sendable {
    case one(Date)
    case ambiguous(earlier: Date, later: Date)
    case missing
}

public struct QuarterMark: Equatable, Sendable, Identifiable {
    public var minute: Int
    public var you: Bool
    public var them: Bool

    public var id: Int { minute }

    public init(minute: Int, you: Bool, them: Bool) {
        self.minute = minute
        self.you = you
        self.them = them
    }
}

public struct SharedSpan: Equatable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public struct DayOverlap: Equatable, Sendable {
    public var quarters: [QuarterMark]
    public var shared: [SharedSpan]
}

public enum MeetingMath {
    /// Places a wall-clock time on a civil date inside `zone`.
    /// A clock change can skip an hour, or repeat it. Both are reported.
    public static func resolve(time: WallTime, on day: CivilDay, in zone: TimeZone) -> TimeMatch {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        var parts = day.dateComponents
        parts.hour = time.hour
        parts.minute = time.minute
        parts.second = 0
        parts.timeZone = zone

        guard let guess = calendar.date(from: parts) else { return .missing }

        let roundTrip = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: guess)
        guard roundTrip.year == day.year,
              roundTrip.month == day.month,
              roundTrip.day == day.day,
              roundTrip.hour == time.hour,
              roundTrip.minute == time.minute
        else {
            return .missing
        }

        var matches = Set<Date>([guess])
        for delta in [-3600.0, 3600.0] {
            let other = guess.addingTimeInterval(delta)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: other)
            if components.year == day.year,
               components.month == day.month,
               components.day == day.day,
               components.hour == time.hour,
               components.minute == time.minute {
                matches.insert(other)
            }
        }

        let ordered = matches.sorted()
        if ordered.count >= 2 {
            return .ambiguous(earlier: ordered[0], later: ordered[1])
        }
        return .one(ordered[0])
    }

    public static func side(at date: Date, zone: TimeZone, work: Workday) -> SideState {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if minutes < work.start.minutes { return .early }
        if minutes >= work.end.minutes { return .late }
        return .inHours
    }

    public static func verdict(you: SideState, them: SideState) -> Verdict {
        switch (you, them) {
        case (.inHours, .inHours):
            return Verdict(tone: .good, sentence: "Works for both.")
        case (.early, .inHours):
            return Verdict(tone: .mixed, sentence: "Early for you. Fine for the client.")
        case (.late, .inHours):
            return Verdict(tone: .mixed, sentence: "Late for you. Fine for the client.")
        case (.inHours, .early):
            return Verdict(tone: .mixed, sentence: "Fine for you. Early for the client.")
        case (.inHours, .late):
            return Verdict(tone: .mixed, sentence: "Fine for you. Late for the client.")
        case (.early, .early):
            return Verdict(tone: .bad, sentence: "Early for both.")
        case (.late, .late):
            return Verdict(tone: .bad, sentence: "Late for both.")
        case (.early, .late):
            return Verdict(tone: .bad, sentence: "Early for you. Late for the client.")
        case (.late, .early):
            return Verdict(tone: .bad, sentence: "Late for you. Early for the client.")
        }
    }

    /// Samples your local day every 15 minutes.
    /// Nepal is 45 minutes off the hour, so a 30 minute grid would miss the shared edge.
    public static func overlap(
        on day: CivilDay,
        yourZone: TimeZone,
        theirZone: TimeZone,
        yourWork: Workday,
        theirWork: Workday
    ) -> DayOverlap {
        var quarters: [QuarterMark] = []
        quarters.reserveCapacity(96)

        for minute in stride(from: 0, to: 24 * 60, by: 15) {
            let time = WallTime(minutes: minute)
            switch resolve(time: time, on: day, in: yourZone) {
            case .missing:
                quarters.append(QuarterMark(minute: minute, you: false, them: false))
            case .one(let date), .ambiguous(let date, _):
                let you = side(at: date, zone: yourZone, work: yourWork) == .inHours
                let them = side(at: date, zone: theirZone, work: theirWork) == .inHours
                quarters.append(QuarterMark(minute: minute, you: you, them: them))
            }
        }

        var shared: [SharedSpan] = []
        var runStart: Int?
        for quarter in quarters {
            if quarter.you && quarter.them {
                if runStart == nil { runStart = quarter.minute }
            } else if let start = runStart {
                shared.append(span(from: start, to: quarter.minute, on: day, zone: yourZone))
                runStart = nil
            }
        }
        if let start = runStart {
            shared.append(span(from: start, to: 24 * 60, on: day, zone: yourZone))
        }

        return DayOverlap(quarters: quarters, shared: shared)
    }

    public static func difference(yourZone: TimeZone, theirZone: TimeZone, theirCity: String, at date: Date) -> String {
        let minutes = (theirZone.secondsFromGMT(for: date) - yourZone.secondsFromGMT(for: date)) / 60
        if minutes == 0 { return "Same time as you." }

        let ahead = minutes > 0
        let span = durationLabel(minutes: abs(minutes))
        let relation = ahead ? "ahead of you" : "behind you"
        return "\(theirCity) is \(span) \(relation)."
    }

    public static func clock(_ date: Date, zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    public static func dayLabel(_ date: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = zone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    public static func civilLabel(_ day: CivilDay) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = CivilDay.gregorian.timeZone
        formatter.calendar = CivilDay.gregorian
        formatter.dateFormat = "EEE d MMM"
        guard let date = CivilDay.gregorian.date(from: day.dateComponents) else { return "" }
        return formatter.string(from: date)
    }

    public static func offsetLabel(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        if minutes == 0 { return "GMT\(sign)\(hours)" }
        return String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }

    public static func zoneAbbreviation(_ zone: TimeZone, at date: Date) -> String {
        if let abbreviation = zone.abbreviation(for: date),
           abbreviation.allSatisfy(\.isLetter),
           abbreviation.count <= 5 {
            return abbreviation
        }
        if let name = stableAbbreviations[zone.identifier] {
            return name
        }
        return offsetLabel(zone, at: date)
    }

    /// Zones whose system abbreviation is a GMT offset. These names do not change with the season.
    private static let stableAbbreviations = [
        "Asia/Kathmandu": "NPT",
        "Asia/Kolkata": "IST",
        "Asia/Hong_Kong": "HKT",
        "Asia/Bangkok": "ICT",
        "Asia/Singapore": "SGT",
        "Asia/Dubai": "GST",
        "Asia/Tokyo": "JST",
    ]

    public static func rangeLabel(start: Date, end: Date, zone: TimeZone, day: CivilDay) -> String {
        let startText = clock(start, zone: zone)
        let endText = endClock(end, zone: zone, day: day)
        if endText == "24:00" { return "\(startText)-24:00" }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let startParts = calendar.dateComponents([.year, .month, .day], from: start)
        let endParts = calendar.dateComponents([.year, .month, .day], from: end)
        let sameDay = startParts.year == endParts.year
            && startParts.month == endParts.month
            && startParts.day == endParts.day
        if sameDay { return "\(startText)-\(endText)" }
        return "\(startText)-\(endText) +1"
    }

    public static func reply(
        spoken: WallTime,
        spokenCity: String,
        instant: Date,
        otherZone: TimeZone,
        otherCity: String,
        side: InputSide,
        verdict: Verdict
    ) -> String {
        let otherClock = clock(instant, zone: otherZone)
        switch side {
        case .theirs:
            return "\(spoken.label) \(spokenCity) is \(otherClock) for me. \(verdict.sentence)"
        case .mine:
            return "\(spoken.label) my time is \(otherClock) in \(otherCity). \(verdict.sentence)"
        }
    }

    private static func endClock(_ date: Date, zone: TimeZone, day: CivilDay) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let next = day.adding(days: 1)
        if parts.year == next.year, parts.month == next.month, parts.day == next.day, parts.hour == 0, parts.minute == 0 {
            return "24:00"
        }
        return clock(date, zone: zone)
    }

    private static func span(from startMinute: Int, to endMinute: Int, on day: CivilDay, zone: TimeZone) -> SharedSpan {
        SharedSpan(
            start: instant(minute: startMinute, on: day, zone: zone),
            end: instant(minute: endMinute, on: day, zone: zone)
        )
    }

    private static func instant(minute: Int, on day: CivilDay, zone: TimeZone) -> Date {
        if minute >= 24 * 60 {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let parts = day.adding(days: 1).dateComponents
            return calendar.date(from: parts) ?? .now
        }

        switch resolve(time: WallTime(minutes: minute), on: day, in: zone) {
        case .one(let date), .ambiguous(let date, _):
            return date
        case .missing:
            return .now
        }
    }

    private static func durationLabel(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}
