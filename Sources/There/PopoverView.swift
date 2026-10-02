import AppKit
import ServiceManagement
import SwiftUI
import ThereCore

struct PopoverView: View {
    @Environment(ClockStore.self) private var store
    @State private var picking: ZoneTarget?
    @State private var showsHours = false
    @State private var loginError = false
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @FocusState private var timeFocused: Bool
    @Environment(\.menuItemHidden) private var menuItemHidden

    private let largeTime = Font.system(size: 26, weight: .light).monospacedDigit()

    var body: some View {
        if let picking {
            picker(picking)
        } else {
            main
        }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            clocks
            divider
            converter
            divider
            settings
        }
        .padding(6)
        .frame(width: 320)
        .onAppear {
            PopoverWindow.makeKey()
            opensAtLogin = SMAppService.mainApp.status == .enabled
            DispatchQueue.main.async {
                timeFocused = true
            }
        }
    }

    private var divider: some View {
        Divider()
            .padding(.horizontal, Theme.inset)
            .padding(.vertical, 6)
    }

    // MARK: - Clocks

    private var clocks: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 0) {
                clockRow(
                    city: store.yourCity.city,
                    detail: store.followsMac ? nil : "Pinned",
                    time: MeetingMath.clock(context.date, zone: store.yourZone),
                    action: { picking = .you }
                )
                clockRow(
                    city: store.theirCity.city,
                    detail: relativeOffset(at: context.date),
                    time: MeetingMath.clock(context.date, zone: store.theirZone),
                    action: { picking = .client }
                )
            }
        }
    }

    private func clockRow(city: String, detail: String?, time: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(city)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(time)
                    .font(largeTime)
            }
        }
        .buttonStyle(.row)
        .help("Choose a city")
    }

    /// Reads like the world clock in the Clock app: "Tomorrow, +3:45".
    private func relativeOffset(at date: Date) -> String {
        let minutes = (store.theirZone.secondsFromGMT(for: date) - store.yourZone.secondsFromGMT(for: date)) / 60
        guard minutes != 0 else { return "Same time" }

        let yourDay = CivilDay.today(in: store.yourZone, now: date)
        let theirDay = CivilDay.today(in: store.theirZone, now: date)
        let dayName = if theirDay == yourDay {
            "Today"
        } else if theirDay == yourDay.adding(days: 1) {
            "Tomorrow"
        } else {
            "Yesterday"
        }

        let sign = minutes > 0 ? "+" : "-"
        return String(format: "%@, %@%d:%02d", dayName, sign, abs(minutes) / 60, abs(minutes) % 60)
    }

    // MARK: - Converter

    private var converter: some View {
        @Bindable var store = store

        return VStack(alignment: .leading, spacing: 0) {
            dayNavigator

            HStack {
                Button {
                    store.side = store.side == .theirs ? .mine : .theirs
                } label: {
                    HStack(spacing: 5) {
                        Text(sourceCity)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Swap which side the time comes from")

                Spacer(minLength: 8)

                TextField("15:00", text: $store.timeText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(largeTime)
                    .frame(width: 96)
                    .padding(.horizontal, 6)
                    .background(.primary.opacity(0.05), in: .rect(cornerRadius: 6, style: .continuous))
                    .focused($timeFocused)
            }
            .padding(.horizontal, Theme.inset)
            .padding(.vertical, 3)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(answerCity)
                    if let answerDay {
                        Text(answerDay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(answerTime ?? "--:--")
                    .font(largeTime)
                    .foregroundStyle(answerTime == nil ? .tertiary : .primary)
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, Theme.inset)
            .padding(.vertical, 3)

            if let status {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.tone(status.tone))
                        .frame(width: 6, height: 6)
                    Text(status.text)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
                .padding(.horizontal, Theme.inset)
                .padding(.top, 4)
            }

            sharedHours
                .padding(.horizontal, Theme.inset)
                .padding(.top, 14)
                .padding(.bottom, 4)
        }
    }

    private var dayNavigator: some View {
        let today = CivilDay.today(in: sourceZone)

        return HStack(spacing: 0) {
            stepButton("chevron.left", help: "Previous day") {
                store.day = store.day.adding(days: -1)
            }
            Text(MeetingMath.civilLabel(store.day))
                .font(.callout.weight(.medium).monospacedDigit())
                .frame(minWidth: 80)
            stepButton("chevron.right", help: "Next day") {
                store.day = store.day.adding(days: 1)
            }

            Spacer()

            Button("Today") {
                store.day = today
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .opacity(store.day == today ? 0 : 1)
            .disabled(store.day == today)
        }
        .padding(.horizontal, Theme.inset - 6)
        .padding(.bottom, 4)
    }

    private func stepButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var spoken: WallTime? {
        WallTime.parse(store.timeText)
    }

    private var hasInput: Bool {
        !store.timeText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var sourceZone: TimeZone {
        store.side == .theirs ? store.theirZone : store.yourZone
    }

    private var answerZone: TimeZone {
        store.side == .theirs ? store.yourZone : store.theirZone
    }

    private var sourceCity: String {
        store.side == .theirs ? store.theirCity.city : store.yourCity.city
    }

    private var answerCity: String {
        store.side == .theirs ? store.yourCity.city : store.theirCity.city
    }

    private var match: TimeMatch? {
        spoken.map { MeetingMath.resolve(time: $0, on: store.day, in: sourceZone) }
    }

    private var answerDate: Date? {
        switch match {
        case .one(let date), .ambiguous(let date, _): date
        case .missing, nil: nil
        }
    }

    private var answerTime: String? {
        answerDate.map { MeetingMath.clock($0, zone: answerZone) }
    }

    /// Only shown when the answer lands on another day than the one picked.
    private var answerDay: String? {
        guard let answerDate, CivilDay.today(in: answerZone, now: answerDate) != store.day else { return nil }
        return MeetingMath.dayLabel(answerDate, zone: answerZone)
    }

    private var status: (tone: Verdict.Tone, text: String)? {
        guard hasInput else { return nil }

        switch match {
        case nil:
            return (.bad, "Use 15:00, 3pm, or 15u30.")
        case .missing:
            return (.bad, "That time does not exist. The clock skips it.")
        case .one(let date):
            return (verdict(at: date).tone, verdict(at: date).sentence)
        case .ambiguous(let earlier, let later):
            let second = MeetingMath.clock(later, zone: answerZone)
            return (.mixed, "This hour happens twice. The second one is \(second). \(verdict(at: earlier).sentence)")
        }
    }

    private func verdict(at date: Date) -> Verdict {
        MeetingMath.verdict(
            you: MeetingMath.side(at: date, zone: store.yourZone, work: store.yourWork),
            them: MeetingMath.side(at: date, zone: store.theirZone, work: store.theirWork)
        )
    }

    // MARK: - Shared hours

    private var sharedHours: some View {
        let overlap = MeetingMath.overlap(
            on: store.day,
            yourZone: store.yourZone,
            theirZone: store.theirZone,
            yourWork: store.yourWork,
            theirWork: store.theirWork
        )

        return VStack(alignment: .leading, spacing: 6) {
            TimelineView(.everyMinute) { context in
                AvailabilityChart(
                    lanes: [store.yourCity.city, store.theirCity.city],
                    quarters: overlap.quarters,
                    nowMinute: nowMinute(at: context.date)
                )
            }

            Text(sharedSummary(overlap))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nowMinute(at date: Date) -> Int? {
        guard store.day == CivilDay.today(in: store.yourZone, now: date) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = store.yourZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private func sharedSummary(_ overlap: DayOverlap) -> String {
        guard !overlap.shared.isEmpty else {
            return "No shared hours on this day."
        }

        let yours = overlap.shared.map {
            MeetingMath.rangeLabel(start: $0.start, end: $0.end, zone: store.yourZone, day: store.day)
        }.joined(separator: ", ")

        let theirs = overlap.shared.map {
            MeetingMath.rangeLabel(start: $0.start, end: $0.end, zone: store.theirZone, day: store.day)
        }.joined(separator: ", ")

        return "Both work \(yours), \(theirs) in \(store.theirCity.city)."
    }

    // MARK: - Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    showsHours.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Working Hours")
                    Spacer()
                    if !showsHours {
                        Text(hoursSummary)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showsHours ? 90 : 0))
                }
            }
            .buttonStyle(.row)

            if showsHours {
                VStack(alignment: .leading, spacing: 6) {
                    hourEditor(store.yourCity.city, start: store.yourWork.start, end: store.yourWork.end, setStart: store.setYourStart, setEnd: store.setYourEnd)
                    hourEditor(store.theirCity.city, start: store.theirWork.start, end: store.theirWork.end, setStart: store.setClientStart, setEnd: store.setClientEnd)
                }
                .padding(.horizontal, Theme.inset)
                .padding(.vertical, 4)
            }

            HStack {
                Text("Open at Login")
                Spacer()
                Toggle("Open at Login", isOn: loginBinding)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            .padding(.horizontal, Theme.inset)
            .padding(.vertical, 5)

            if loginError {
                footnote("macOS did not allow the login item.")
            }

            if menuItemHidden {
                footnote("The menu bar item is off screen. Quit Hidden Bar, hold Command, and drag There next to the clock.")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Text("Quit There")
                    Spacer()
                    Text("⌘Q")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.row)
            .keyboardShortcut("q")
        }
    }

    private var hoursSummary: String {
        store.yourWork == store.theirWork ? store.yourWork.label : "Different"
    }

    private func hourEditor(
        _ city: String,
        start: WallTime,
        end: WallTime,
        setStart: @escaping (WallTime) -> Void,
        setEnd: @escaping (WallTime) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text(city)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            timePicker(start, set: setStart)
            Text("to")
                .foregroundStyle(.secondary)
            timePicker(end, set: setEnd)
        }
        .environment(\.locale, Locale(identifier: "en_GB"))
    }

    private func timePicker(_ time: WallTime, set: @escaping (WallTime) -> Void) -> some View {
        DatePicker(
            "",
            selection: Binding(
                get: { date(from: time) },
                set: { set(wallTime(from: $0)) }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.stepperField)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.inset)
            .padding(.bottom, 4)
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { opensAtLogin },
            set: { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    opensAtLogin = SMAppService.mainApp.status == .enabled
                    loginError = false
                } catch {
                    opensAtLogin = SMAppService.mainApp.status == .enabled
                    loginError = true
                }
            }
        )
    }

    // MARK: - City picker

    private func picker(_ target: ZoneTarget) -> some View {
        CityPicker(
            target: target,
            currentID: target == .you ? store.yourZone.identifier : store.theirZone.identifier,
            followsMac: store.followsMac,
            onPick: { identifier in
                if target == .you {
                    store.chooseYourZone(identifier)
                } else {
                    store.chooseClientZone(identifier)
                }
                picking = nil
            },
            onUseMac: {
                store.useMacZone()
                picking = nil
            },
            onClose: { picking = nil }
        )
    }

    // MARK: - Helpers

    private func date(from time: WallTime) -> Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        parts.hour = time.hour
        parts.minute = time.minute
        return Calendar.current.date(from: parts) ?? .now
    }

    private func wallTime(from date: Date) -> WallTime {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return WallTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}

/// One lane per city across your day. Shared hours turn green on both lanes.
private struct AvailabilityChart: View {
    var lanes: [String]
    var quarters: [QuarterMark]
    var nowMinute: Int?

    private let laneHeight: CGFloat = 12
    private let laneGap: CGFloat = 4
    private let barHeight: CGFloat = 4
    private let labelWidth: CGFloat = 70

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: laneGap) {
                    ForEach(lanes, id: \.self) { lane in
                        Text(lane)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(height: laneHeight)
                    }
                }
                .frame(width: labelWidth, alignment: .leading)

                Canvas { context, size in
                    draw(in: &context, size: size)
                }
                .frame(height: laneHeight * 2 + laneGap)
            }

            hourTicks
                .padding(.leading, labelWidth)
        }
        .accessibilityElement()
        .accessibilityLabel("Working hours across your day. Shared hours are green.")
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard !quarters.isEmpty else { return }
        let step = size.width / CGFloat(quarters.count)
        let laneMatches: [(QuarterMark) -> Bool] = [{ $0.you }, { $0.them }]

        for (index, matches) in laneMatches.enumerated() {
            let y = CGFloat(index) * (laneHeight + laneGap) + (laneHeight - barHeight) / 2

            func bar(_ run: Range<Int>, _ color: Color) {
                let rect = CGRect(x: CGFloat(run.lowerBound) * step, y: y, width: CGFloat(run.count) * step, height: barHeight)
                context.fill(Path(roundedRect: rect, cornerRadius: barHeight / 2), with: .color(color))
            }

            bar(0..<quarters.count, .primary.opacity(0.07))
            runs(where: matches).forEach { bar($0, .primary.opacity(0.28)) }
            runs(where: { $0.you && $0.them }).forEach { bar($0, .green) }
        }

        if let nowMinute {
            let x = size.width * CGFloat(nowMinute) / (24 * 60)
            context.fill(Path(CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)), with: .color(.red))
        }
    }

    private func runs(where matches: (QuarterMark) -> Bool) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start: Int?
        for (index, quarter) in quarters.enumerated() {
            if matches(quarter) {
                if start == nil { start = index }
            } else if let runStart = start {
                runs.append(runStart..<index)
                start = nil
            }
        }
        if let start {
            runs.append(start..<quarters.count)
        }
        return runs
    }

    private var hourTicks: some View {
        GeometryReader { proxy in
            ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .position(
                        x: min(max(proxy.size.width * CGFloat(hour) / 24, 6), proxy.size.width - 6),
                        y: 5
                    )
            }
        }
        .frame(height: 10)
    }
}

private struct MenuItemHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var menuItemHidden: Bool {
        get { self[MenuItemHiddenKey.self] }
        set { self[MenuItemHiddenKey.self] = newValue }
    }
}

@MainActor
enum PopoverWindow {
    /// A menu bar panel can open without becoming key. The time field then ignores typing.
    static func makeKey() {
        NSApp.activate()
        for window in NSApp.windows where window.canBecomeKey {
            window.makeKey()
        }
    }
}
