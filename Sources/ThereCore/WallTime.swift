import Foundation

public struct WallTime: Equatable, Sendable, Hashable {
    public var hour: Int
    public var minute: Int

    public var minutes: Int { hour * 60 + minute }

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init(minutes: Int) {
        let clamped = min(max(minutes, 0), 24 * 60)
        hour = clamped / 60
        minute = clamped % 60
    }

    public var label: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Reads a meeting time from a short note.
    /// Accepts 15:00, 15.00, 15, 1530, 3pm, 3:30 pm, 15u, 15u30, and "om 15:00".
    public static func parse(_ raw: String) -> WallTime? {
        var text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        text = text.replacingOccurrences(of: "uur", with: "")
        if let om = text.range(of: #"^om\s+"#, options: .regularExpression) {
            text.removeSubrange(om)
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var period: Period?
        if let range = text.range(of: #"\s*(a\.?m\.?|p\.?m\.?)$"#, options: .regularExpression) {
            let letters = text[range].filter(\.isLetter)
            period = letters == "pm" ? .pm : .am
            text.removeSubrange(range)
        }

        text = text.replacingOccurrences(of: " ", with: "")
        text = text.replacingOccurrences(of: ".", with: ":")
        text = text.replacingOccurrences(of: "u", with: ":")
        guard !text.isEmpty else { return nil }

        let hour: Int
        let minute: Int

        if text.allSatisfy(\.isNumber) {
            switch text.count {
            case 1, 2:
                hour = Int(text) ?? -1
                minute = 0
            case 3:
                hour = Int(text.prefix(1)) ?? -1
                minute = Int(text.suffix(2)) ?? -1
            case 4:
                hour = Int(text.prefix(2)) ?? -1
                minute = Int(text.suffix(2)) ?? -1
            default:
                return nil
            }
        } else {
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count >= 2, parts.count <= 3 else { return nil }
            guard let parsedHour = Int(parts[0]), parts[0].allSatisfy(\.isNumber) else { return nil }
            let minuteText = String(parts[1])
            if minuteText.isEmpty {
                minute = 0
            } else if minuteText.allSatisfy(\.isNumber), let parsedMinute = Int(minuteText) {
                minute = parsedMinute
            } else {
                return nil
            }
            hour = parsedHour
        }

        guard (0...59).contains(minute) else { return nil }

        var resolvedHour = hour
        if let period {
            guard (1...12).contains(resolvedHour) else { return nil }
            if resolvedHour == 12 { resolvedHour = 0 }
            if period == .pm { resolvedHour += 12 }
        }

        guard (0...23).contains(resolvedHour) else { return nil }
        return WallTime(hour: resolvedHour, minute: minute)
    }

    private enum Period {
        case am
        case pm
    }
}

public struct Workday: Equatable, Sendable, Hashable {
    public var start: WallTime
    public var end: WallTime

    public static let standard = Workday(
        start: WallTime(hour: 9, minute: 0),
        end: WallTime(hour: 17, minute: 30)
    )

    public var isValid: Bool { end.minutes > start.minutes }

    public var label: String { "\(start.label)-\(end.label)" }

    public init(start: WallTime, end: WallTime) {
        self.start = start
        self.end = end
    }
}
