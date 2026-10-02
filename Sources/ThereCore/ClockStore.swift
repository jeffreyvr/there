import Foundation
import Observation

public struct LaunchOverrides: Equatable, Sendable {
    public var yourZoneID: String?
    public var clientZoneID: String?
    public var timeText: String?
    public var side: InputSide?
    public var day: CivilDay?

    public init(
        yourZoneID: String? = nil,
        clientZoneID: String? = nil,
        timeText: String? = nil,
        side: InputSide? = nil,
        day: CivilDay? = nil
    ) {
        self.yourZoneID = yourZoneID
        self.clientZoneID = clientZoneID
        self.timeText = timeText
        self.side = side
        self.day = day
    }
}

@MainActor
@Observable
public final class ClockStore {
    public var theirZoneID: String {
        didSet { guard isReady else { return }; defaults.set(theirZoneID, forKey: Keys.clientZone) }
    }

    public var yourOverrideID: String? {
        didSet { guard isReady else { return }; saveOverride() }
    }

    public var yourWork: Workday {
        didSet { guard isReady else { return }; saveWork() }
    }

    public var theirWork: Workday {
        didSet { guard isReady else { return }; saveWork() }
    }

    public var timeText: String
    public var side: InputSide
    public var day: CivilDay

    private let defaults: UserDefaults
    private var isReady = false

    public init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults

        let storedClient = defaults.string(forKey: Keys.clientZone)
        let client = storedClient.flatMap { TimeZone(identifier: $0) == nil ? nil : $0 } ?? Cities.clientDefault
        let storedYou = defaults.string(forKey: Keys.yourOverride)
        let override = storedYou.flatMap { TimeZone(identifier: $0) == nil ? nil : $0 }

        var your = Workday(
            start: Self.storedTime(defaults, key: Keys.yourStart, fallback: Workday.standard.start),
            end: Self.storedTime(defaults, key: Keys.yourEnd, fallback: Workday.standard.end)
        )
        var their = Workday(
            start: Self.storedTime(defaults, key: Keys.theirStart, fallback: Workday.standard.start),
            end: Self.storedTime(defaults, key: Keys.theirEnd, fallback: Workday.standard.end)
        )
        if !your.isValid { your = .standard }
        if !their.isValid { their = .standard }

        let zone = override.flatMap(TimeZone.init(identifier:)) ?? .current
        let today = CivilDay.today(in: zone, now: now)

        theirZoneID = client
        yourOverrideID = override
        yourWork = your
        theirWork = their
        timeText = ""
        side = .theirs
        day = today
        isReady = true
    }

    public var yourZone: TimeZone {
        if let yourOverrideID, let zone = TimeZone(identifier: yourOverrideID) {
            return zone
        }
        return .current
    }

    public var theirZone: TimeZone {
        TimeZone(identifier: theirZoneID) ?? TimeZone(identifier: Cities.clientDefault) ?? .current
    }

    public var followsMac: Bool { yourOverrideID == nil }

    public var yourCity: ZoneChoice { Cities.choice(for: yourZone.identifier) }
    public var theirCity: ZoneChoice { Cities.choice(for: theirZone.identifier) }

    public func menuTitle(at date: Date) -> String {
        let client = "\(Cities.code(for: theirZone.identifier)) \(MeetingMath.clock(date, zone: theirZone))"
        guard !followsMac, yourZone.identifier != theirZone.identifier else { return client }
        let you = "\(Cities.code(for: yourZone.identifier)) \(MeetingMath.clock(date, zone: yourZone))"
        return "\(you)  \(client)"
    }

    public func useMacZone() {
        yourOverrideID = nil
    }

    public func chooseYourZone(_ identifier: String) {
        if identifier == TimeZone.current.identifier {
            yourOverrideID = nil
        } else {
            yourOverrideID = identifier
        }
    }

    public func chooseClientZone(_ identifier: String) {
        guard TimeZone(identifier: identifier) != nil else { return }
        theirZoneID = identifier
    }

    public func setYourStart(_ time: WallTime) {
        guard time.minutes < yourWork.end.minutes else { return }
        yourWork.start = time
    }

    public func setYourEnd(_ time: WallTime) {
        guard time.minutes > yourWork.start.minutes else { return }
        yourWork.end = time
    }

    public func setClientStart(_ time: WallTime) {
        guard time.minutes < theirWork.end.minutes else { return }
        theirWork.start = time
    }

    public func setClientEnd(_ time: WallTime) {
        guard time.minutes > theirWork.start.minutes else { return }
        theirWork.end = time
    }

    public func apply(_ overrides: LaunchOverrides, now: Date = .now) {
        if let clientZoneID = overrides.clientZoneID, TimeZone(identifier: clientZoneID) != nil {
            theirZoneID = clientZoneID
        }
        if let yourZoneID = overrides.yourZoneID {
            chooseYourZone(yourZoneID)
        }
        if let timeText = overrides.timeText {
            self.timeText = timeText
        }
        if let side = overrides.side {
            self.side = side
        }
        if let day = overrides.day {
            self.day = day
        } else if overrides.yourZoneID != nil {
            day = CivilDay.today(in: yourZone, now: now)
        }
    }

    private func saveOverride() {
        if let yourOverrideID {
            defaults.set(yourOverrideID, forKey: Keys.yourOverride)
        } else {
            defaults.removeObject(forKey: Keys.yourOverride)
        }
    }

    private func saveWork() {
        defaults.set(yourWork.start.minutes, forKey: Keys.yourStart)
        defaults.set(yourWork.end.minutes, forKey: Keys.yourEnd)
        defaults.set(theirWork.start.minutes, forKey: Keys.theirStart)
        defaults.set(theirWork.end.minutes, forKey: Keys.theirEnd)
    }

    private static func storedTime(_ defaults: UserDefaults, key: String, fallback: WallTime) -> WallTime {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return WallTime(minutes: defaults.integer(forKey: key))
    }

    private enum Keys {
        static let clientZone = "clientZoneID"
        static let yourOverride = "yourOverrideID"
        static let yourStart = "yourWorkStart"
        static let yourEnd = "yourWorkEnd"
        static let theirStart = "clientWorkStart"
        static let theirEnd = "clientWorkEnd"
    }
}
