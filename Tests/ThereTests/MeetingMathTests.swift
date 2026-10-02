import Foundation
import Testing
@testable import ThereCore

private let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
private let kathmandu = TimeZone(identifier: "Asia/Kathmandu")!
private let hongKong = TimeZone(identifier: "Asia/Hong_Kong")!
private let bangkok = TimeZone(identifier: "Asia/Bangkok")!
private let singapore = TimeZone(identifier: "Asia/Singapore")!

private let summer = CivilDay(year: 2026, month: 7, day: 15)
private let winter = CivilDay(year: 2026, month: 1, day: 15)

struct WallTimeTests {
    @Test(arguments: [
        ("15:00", 15, 0),
        ("15.00", 15, 0),
        ("15", 15, 0),
        ("9", 9, 0),
        ("1530", 15, 30),
        ("930", 9, 30),
        ("3pm", 15, 0),
        ("3:30 pm", 15, 30),
        ("3:30pm", 15, 30),
        ("12am", 0, 0),
        ("12pm", 12, 0),
        ("12:30am", 0, 30),
        ("15u", 15, 0),
        ("15u30", 15, 30),
        ("15 uur", 15, 0),
        ("om 10:00", 10, 0),
        ("om 9.30", 9, 30),
    ])
    func parsesMeetingNotes(raw: String, hour: Int, minute: Int) {
        #expect(WallTime.parse(raw) == WallTime(hour: hour, minute: minute))
    }

    @Test(arguments: ["", "hello", "25:00", "15:60", "3:70pm"])
    func rejectsUnusableText(raw: String) {
        #expect(WallTime.parse(raw) == nil)
    }
}

struct CivilDayTests {
    @Test func stepsAcrossMonthEnd() {
        let day = CivilDay(year: 2026, month: 1, day: 31)
        #expect(day.adding(days: 1) == CivilDay(year: 2026, month: 2, day: 1))
        #expect(day.adding(days: -1) == CivilDay(year: 2026, month: 1, day: 30))
    }
}

struct ConversionTests {
    @Test func summerAfternoonFromAmsterdam() {
        expect("15:00", on: summer, from: amsterdam, to: kathmandu, is: "18:45")
        expect("15:00", on: summer, from: amsterdam, to: hongKong, is: "21:00")
        expect("15:00", on: summer, from: amsterdam, to: bangkok, is: "20:00")
        expect("15:00", on: summer, from: amsterdam, to: singapore, is: "21:00")
    }

    @Test func winterAfternoonFromAmsterdam() {
        expect("15:00", on: winter, from: amsterdam, to: kathmandu, is: "19:45")
        expect("15:00", on: winter, from: amsterdam, to: hongKong, is: "22:00")
        expect("15:00", on: winter, from: amsterdam, to: bangkok, is: "21:00")
        expect("15:00", on: winter, from: amsterdam, to: singapore, is: "22:00")
    }

    @Test func springForwardSkipsTheMissingHour() {
        let match = MeetingMath.resolve(
            time: WallTime(hour: 2, minute: 30),
            on: CivilDay(year: 2026, month: 3, day: 29),
            in: amsterdam
        )
        #expect(match == .missing)
    }

    @Test func fallBackRepeatsTheHour() {
        let match = MeetingMath.resolve(
            time: WallTime(hour: 2, minute: 30),
            on: CivilDay(year: 2026, month: 10, day: 25),
            in: amsterdam
        )
        guard case .ambiguous(let earlier, let later) = match else {
            Issue.record("Expected the repeated hour")
            return
        }
        #expect(MeetingMath.clock(earlier, zone: kathmandu) == "06:15")
        #expect(MeetingMath.clock(later, zone: kathmandu) == "07:15")
    }

    private func expect(_ label: String, on day: CivilDay, from: TimeZone, to: TimeZone, is expected: String) {
        let time = WallTime.parse(label)!
        let match = MeetingMath.resolve(time: time, on: day, in: from)
        guard case .one(let date) = match else {
            Issue.record("Expected one instant for \(label)")
            return
        }
        #expect(MeetingMath.clock(date, zone: to) == expected)
    }
}

struct VerdictTests {
    @Test func nepalSummerAfternoonIsLateForYou() {
        let verdict = check(hour: 15, minute: 0, on: summer, you: kathmandu, client: amsterdam)
        #expect(verdict == Verdict(tone: .mixed, sentence: "Late for you. Fine for the client."))
    }

    @Test func nepalSummerMorningWorks() {
        let verdict = check(hour: 10, minute: 0, on: summer, you: kathmandu, client: amsterdam)
        #expect(verdict == Verdict(tone: .good, sentence: "Works for both."))
    }

    @Test func offeredMorningIsEarlyForAmsterdam() {
        let date = resolved(hour: 9, minute: 0, on: summer, zone: kathmandu)
        let verdict = MeetingMath.verdict(
            you: MeetingMath.side(at: date, zone: kathmandu, work: .standard),
            them: MeetingMath.side(at: date, zone: amsterdam, work: .standard)
        )
        #expect(verdict.sentence == "Fine for you. Early for the client.")
        let line = MeetingMath.reply(
            spoken: WallTime(hour: 9, minute: 0),
            spokenCity: "Kathmandu",
            instant: date,
            otherZone: amsterdam,
            otherCity: "Amsterdam",
            side: .mine,
            verdict: verdict
        )
        #expect(line == "09:00 my time is 05:15 in Amsterdam. Fine for you. Early for the client.")
    }

    @Test func boundaryIsClosedAtTheEndOfTheDay() {
        let inside = resolved(hour: 17, minute: 15, on: summer, zone: amsterdam)
        let edge = resolved(hour: 17, minute: 30, on: summer, zone: amsterdam)
        #expect(MeetingMath.side(at: inside, zone: amsterdam, work: .standard) == .inHours)
        #expect(MeetingMath.side(at: edge, zone: amsterdam, work: .standard) == .late)
    }

    private func check(hour: Int, minute: Int, on day: CivilDay, you: TimeZone, client: TimeZone) -> Verdict {
        let date = resolved(hour: hour, minute: minute, on: day, zone: client)
        return MeetingMath.verdict(
            you: MeetingMath.side(at: date, zone: you, work: .standard),
            them: MeetingMath.side(at: date, zone: client, work: .standard)
        )
    }

    private func resolved(hour: Int, minute: Int, on day: CivilDay, zone: TimeZone) -> Date {
        let match = MeetingMath.resolve(time: WallTime(hour: hour, minute: minute), on: day, in: zone)
        guard case .one(let date) = match else {
            Issue.record("Missing instant")
            return .now
        }
        return date
    }
}

struct OverlapTests {
    @Test func summerKathmanduWindow() {
        let overlap = MeetingMath.overlap(
            on: summer,
            yourZone: kathmandu,
            theirZone: amsterdam,
            yourWork: .standard,
            theirWork: .standard
        )
        #expect(overlap.shared.count == 1)
        expect(overlap.shared[0], on: summer, yours: kathmandu, is: "12:45-17:30")
        expect(overlap.shared[0], on: summer, yours: amsterdam, is: "09:00-13:45")
    }

    @Test func winterKathmanduWindow() {
        let overlap = MeetingMath.overlap(
            on: winter,
            yourZone: kathmandu,
            theirZone: amsterdam,
            yourWork: .standard,
            theirWork: .standard
        )
        #expect(overlap.shared.count == 1)
        expect(overlap.shared[0], on: winter, yours: kathmandu, is: "13:45-17:30")
        expect(overlap.shared[0], on: winter, yours: amsterdam, is: "09:00-12:45")
    }

    @Test func summerEastAsiaWindows() {
        expectWindow(your: hongKong, on: summer, yours: "15:00-17:30", client: "09:00-11:30")
        expectWindow(your: singapore, on: summer, yours: "15:00-17:30", client: "09:00-11:30")
        expectWindow(your: bangkok, on: summer, yours: "14:00-17:30", client: "09:00-12:30")
    }

    @Test func winterHongKongWindowIsShort() {
        expectWindow(your: hongKong, on: winter, yours: "16:00-17:30", client: "09:00-10:30")
    }

    @Test func sameZoneSharesTheWholeDay() {
        let overlap = MeetingMath.overlap(
            on: summer,
            yourZone: amsterdam,
            theirZone: amsterdam,
            yourWork: .standard,
            theirWork: .standard
        )
        #expect(overlap.shared.count == 1)
        expect(overlap.shared[0], on: summer, yours: amsterdam, is: "09:00-17:30")
    }

    @Test func differenceAccountsForNepalOffset() {
        let noon = ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z")!
        let summerLine = MeetingMath.difference(
            yourZone: kathmandu,
            theirZone: amsterdam,
            theirCity: "Amsterdam",
            at: noon
        )
        #expect(summerLine == "Amsterdam is 3h 45m behind you.")

        let winterNoon = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
        let winterLine = MeetingMath.difference(
            yourZone: kathmandu,
            theirZone: amsterdam,
            theirCity: "Amsterdam",
            at: winterNoon
        )
        #expect(winterLine == "Amsterdam is 4h 45m behind you.")
    }

    private func expectWindow(your: TimeZone, on day: CivilDay, yours: String, client: String) {
        let overlap = MeetingMath.overlap(
            on: day,
            yourZone: your,
            theirZone: amsterdam,
            yourWork: .standard,
            theirWork: .standard
        )
        #expect(overlap.shared.count == 1)
        expect(overlap.shared[0], on: day, yours: your, is: yours)
        expect(overlap.shared[0], on: day, yours: amsterdam, is: client)
    }

    private func expect(_ span: SharedSpan, on day: CivilDay, yours zone: TimeZone, is expected: String) {
        #expect(MeetingMath.rangeLabel(start: span.start, end: span.end, zone: zone, day: day) == expected)
    }
}

struct CityTests {
    @Test func kathmanduShowsNepalTime() {
        let zone = TimeZone(identifier: "Asia/Kathmandu")!
        #expect(MeetingMath.zoneAbbreviation(zone, at: .now) == "NPT")
    }

    @Test func pinsTheTripList() {
        #expect(Cities.pinned.first?.identifier == "Europe/Amsterdam")
        #expect(Cities.code(for: "Asia/Kathmandu") == "KTM")
        #expect(Cities.code(for: "Asia/Hong_Kong") == "HKG")
        #expect(Cities.code(for: "Asia/Bangkok") == "BKK")
        #expect(Cities.code(for: "Asia/Singapore") == "SIN")
    }

    @Test func searchFindsKathmandu() {
        let hits = Cities.search("kath")
        #expect(hits.first?.identifier == "Asia/Kathmandu")
        #expect(Cities.search("").count == Cities.pinned.count)
    }
}

@MainActor
struct ClockStoreTests {
    @Test func remembersTheClientZone() {
        let defaults = UserDefaults(suiteName: "ThereTests.zones")!
        defaults.removePersistentDomain(forName: "ThereTests.zones")
        let store = ClockStore(defaults: defaults)
        store.chooseClientZone("Asia/Bangkok")
        store.yourOverrideID = "Asia/Kathmandu"

        let again = ClockStore(defaults: defaults)
        #expect(again.theirZoneID == "Asia/Bangkok")
        #expect(again.yourOverrideID == "Asia/Kathmandu")
        again.chooseClientZone("Europe/Amsterdam")

        let noon = ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z")!
        #expect(again.menuTitle(at: noon) == "KTM 17:45  AMS 14:00")

        let homeDefaults = UserDefaults(suiteName: "ThereTests.home")!
        homeDefaults.removePersistentDomain(forName: "ThereTests.home")
        let home = ClockStore(defaults: homeDefaults)
        home.chooseClientZone("Europe/Amsterdam")
        #expect(home.menuTitle(at: noon) == "AMS 14:00")
        defaults.removePersistentDomain(forName: "ThereTests.zones")
        homeDefaults.removePersistentDomain(forName: "ThereTests.home")
    }

    @Test func rejectsAWorkdayThatRunsBackwards() {
        let defaults = UserDefaults(suiteName: "ThereTests.hours")!
        defaults.removePersistentDomain(forName: "ThereTests.hours")
        let store = ClockStore(defaults: defaults)
        store.setYourEnd(WallTime(hour: 8, minute: 0))
        #expect(store.yourWork == .standard)
        defaults.removePersistentDomain(forName: "ThereTests.hours")
    }
}

struct StatusItemPlacementTests {
    private let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    @Test func itemInTheVisibleMenuBarIsReachable() {
        let item = CGRect(x: 1472, y: 1093, width: 63, height: 24)
        #expect(StatusItemPlacement.isReachable(itemFrame: item, screenFrames: [laptop]))
    }

    @Test func itemAboveAnAutoHiddenMenuBarIsReachable() {
        let item = CGRect(x: 1472, y: 1121, width: 63, height: 24)
        #expect(StatusItemPlacement.isReachable(itemFrame: item, screenFrames: [laptop]))
    }

    @Test func itemParkedByHiddenBarIsNotReachable() {
        let item = CGRect(x: -4129, y: 1121, width: 63, height: 24)
        #expect(!StatusItemPlacement.isReachable(itemFrame: item, screenFrames: [laptop]))
    }

    @Test func itemWithoutWidthIsNotReachable() {
        let item = CGRect(x: 1472, y: 1093, width: 0, height: 24)
        #expect(!StatusItemPlacement.isReachable(itemFrame: item, screenFrames: [laptop]))
    }
}
