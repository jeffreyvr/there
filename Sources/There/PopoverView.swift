import AppKit
import ServiceManagement
import SwiftUI
import ThereCore

struct PopoverView: View {
    @Environment(ClockStore.self) private var store
    @State private var picking: ZoneTarget?
    @State private var showsHours = false
    @State private var copied = false
    @State private var loginError = false
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @FocusState private var timeFocused: Bool
    @Environment(\.menuItemHidden) private var menuItemHidden

    private let chips = [9, 10, 11, 14, 15, 16]

    var body: some View {
        Group {
            if let picking {
                picker(picking)
            } else {
                main
            }
        }
        .background(Theme.paper)
    }

    private var main: some View {
        @Bindable var store = store

        return VStack(alignment: .leading, spacing: 16) {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: 12) {
                    clockRow(
                        kicker: "You",
                        tint: Theme.you,
                        time: MeetingMath.clock(context.date, zone: store.yourZone),
                        place: placeLine(store.yourCity, zone: store.yourZone, at: context.date),
                        note: store.followsMac ? "This Mac" : "Pinned",
                        action: { picking = .you }
                    )
                    clockRow(
                        kicker: "Client",
                        tint: Theme.client,
                        time: MeetingMath.clock(context.date, zone: store.theirZone),
                        place: placeLine(store.theirCity, zone: store.theirZone, at: context.date),
                        note: nil,
                        action: { picking = .client }
                    )
                    Text(clockHint(at: context.date))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            hairline

            VStack(alignment: .leading, spacing: 8) {
                Text("Check a time")
                    .font(.system(size: 12, weight: .semibold))

                Picker("Who said it", selection: $store.side) {
                    Text("Client said").tag(InputSide.theirs)
                    Text("I said").tag(InputSide.mine)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 8) {
                    TextField("15:00", text: $store.timeText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 16, weight: .medium).monospacedDigit())
                        .frame(width: 88)
                        .focused($timeFocused)

                    Spacer(minLength: 8)

                    dayStepper
                }

                if !store.timeText.trimmingCharacters(in: .whitespaces).isEmpty, spoken == nil {
                    Text("Use 15:00, 3pm, or 15u30.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.bad)
                }

                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { hour in
                        chip(hour)
                    }
                }

                resultCards
            }

            hairline

            overlapSection

            hoursSection

            hairline

            footer
        }
        .padding(18)
        .frame(width: 360)
        .onAppear {
            PopoverWindow.makeKey()
            opensAtLogin = SMAppService.mainApp.status == .enabled
            DispatchQueue.main.async {
                timeFocused = true
            }
        }
    }

    private var spoken: WallTime? {
        WallTime.parse(store.timeText)
    }

    private var sourceZone: TimeZone {
        store.side == .theirs ? store.theirZone : store.yourZone
    }

    private var dayStepper: some View {
        HStack(spacing: 2) {
            stepButton("chevron.left", help: "Previous day") {
                store.day = store.day.adding(days: -1)
            }

            Text(MeetingMath.civilLabel(store.day))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .frame(minWidth: 88)

            stepButton("chevron.right", help: "Next day") {
                store.day = store.day.adding(days: 1)
            }

            if store.day != CivilDay.today(in: sourceZone) {
                Button("Today") {
                    store.day = CivilDay.today(in: sourceZone)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.client)
                .padding(.leading, 4)
            }
        }
    }

    @ViewBuilder
    private var resultCards: some View {
        if let spoken {
            switch MeetingMath.resolve(time: spoken, on: store.day, in: sourceZone) {
            case .missing:
                Text("That time does not exist. The clock skips it.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.bad)
            case .one(let date):
                resultCard(date: date, spoken: spoken, kicker: store.side == .theirs ? "For you" : "For the client")
            case .ambiguous(let earlier, let later):
                VStack(alignment: .leading, spacing: 8) {
                    Text("This hour happens twice.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mixed)
                    resultCard(date: earlier, spoken: spoken, kicker: "Earlier")
                    resultCard(date: later, spoken: spoken, kicker: "Later")
                }
            }
        }
    }

    private func resultCard(date: Date, spoken: WallTime, kicker: String) -> some View {
        let answerZone = store.side == .theirs ? store.yourZone : store.theirZone
        let answerCity = store.side == .theirs ? store.yourCity.city : store.theirCity.city
        let verdict = MeetingMath.verdict(
            you: MeetingMath.side(at: date, zone: store.yourZone, work: store.yourWork),
            them: MeetingMath.side(at: date, zone: store.theirZone, work: store.theirWork)
        )
        let line = MeetingMath.reply(
            spoken: spoken,
            spokenCity: store.side == .theirs ? store.theirCity.city : "my time",
            instant: date,
            otherZone: answerZone,
            otherCity: answerCity,
            side: store.side,
            verdict: verdict
        )

        return HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.tone(verdict.tone))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(kicker.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Theme.tone(verdict.tone))

                Text(MeetingMath.clock(date, zone: answerZone))
                    .font(.system(size: 34, weight: .medium).monospacedDigit())

                Text("\(MeetingMath.dayLabel(date, zone: answerZone)) · \(answerCity)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text(verdict.sentence)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.tone(verdict.tone))
                    .fixedSize(horizontal: false, vertical: true)

                Button(copied ? "Copied" : "Copy") {
                    copy(line)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.tone(verdict.tone).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var overlapSection: some View {
        let overlap = MeetingMath.overlap(
            on: store.day,
            yourZone: store.yourZone,
            theirZone: store.theirZone,
            yourWork: store.yourWork,
            theirWork: store.theirWork
        )
        let summary = sharedSummary(overlap)

        return VStack(alignment: .leading, spacing: 8) {
            Text("On \(MeetingMath.civilLabel(store.day))")
                .font(.system(size: 12, weight: .semibold))

            Text(summary.title)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)

            Text(summary.detail)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            OverlapBar(quarters: overlap.quarters)
                .frame(height: 12)

            hourTicks

            HStack(spacing: 12) {
                legendSwatch(Theme.you.opacity(0.55), "You")
                legendSwatch(Theme.client.opacity(0.40), "Client")
                legendSwatch(Theme.client, "Both")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    private var hourTicks: some View {
        GeometryReader { proxy in
            ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                Text("\(hour)")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .position(
                        x: min(max(proxy.size.width * CGFloat(hour) / 24, 8), proxy.size.width - 8),
                        y: 6
                    )
            }
        }
        .frame(height: 12)
    }

    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showsHours.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text("Hours")
                    Spacer()
                    Text(hoursSummary)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Image(systemName: showsHours ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)

            if showsHours {
                hourEditor("You", start: store.yourWork.start, end: store.yourWork.end, setStart: store.setYourStart, setEnd: store.setYourEnd)
                hourEditor("Client", start: store.theirWork.start, end: store.theirWork.end, setStart: store.setClientStart, setEnd: store.setClientEnd)
            }
        }
    }

    private var hoursSummary: String {
        if store.yourWork == store.theirWork {
            return "You and client \(store.yourWork.label)"
        }
        return "You \(store.yourWork.label) · Client \(store.theirWork.label)"
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("There")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("Open at login", isOn: loginBinding)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 11))

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
            }

            if loginError {
                Text("macOS did not allow the login item.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.bad)
            }

            if menuItemHidden {
                Text("The menu item is off screen. Quit Hidden Bar, hold Command, and drag There next to the clock.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }

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

    private func clockRow(
        kicker: String,
        tint: Color,
        time: String,
        place: String,
        note: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(time)
                .font(.system(size: 26, weight: .medium).monospacedDigit())
                .frame(width: 88, alignment: .leading)

            Button(action: action) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(kicker.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(tint)

                    HStack(spacing: 4) {
                        Text(place)
                            .lineLimit(1)
                        if let note {
                            Text(note)
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kicker), \(place), \(time)")
        .accessibilityAddTraits(.isButton)
    }

    private func chip(_ hour: Int) -> some View {
        let label = String(format: "%02d", hour)
        let selected = spoken?.hour == hour && spoken?.minute == 0
        return Button {
            store.timeText = "\(label):00"
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(selected ? Theme.client.opacity(0.16) : Color.primary.opacity(0.06))
                .foregroundStyle(selected ? Theme.client : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    private func hourEditor(
        _ title: String,
        start: WallTime,
        end: WallTime,
        setStart: @escaping (WallTime) -> Void,
        setEnd: @escaping (WallTime) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .frame(width: 48, alignment: .leading)
            timePicker(start, set: setStart)
            Text("to")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            timePicker(end, set: setEnd)
            Spacer(minLength: 0)
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
        .datePickerStyle(.field)
        .frame(width: 86)
    }

    private func legendSwatch(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
        }
    }

    private func clockHint(at date: Date) -> String {
        if store.yourZone.identifier == store.theirZone.identifier {
            return "Same time as you. Pin a city under You to preview a trip."
        }
        return MeetingMath.difference(
            yourZone: store.yourZone,
            theirZone: store.theirZone,
            theirCity: store.theirCity.city,
            at: date
        )
    }

    private func placeLine(_ choice: ZoneChoice, zone: TimeZone, at date: Date) -> String {
        "\(choice.city) · \(MeetingMath.zoneAbbreviation(zone, at: date))"
    }

    private func sharedSummary(_ overlap: DayOverlap) -> (title: String, detail: String) {
        guard !overlap.shared.isEmpty else {
            return ("No shared hours.", "Try another day, or widen the working hours.")
        }

        let yours = overlap.shared.map {
            MeetingMath.rangeLabel(start: $0.start, end: $0.end, zone: store.yourZone, day: store.day)
        }.joined(separator: ", ")

        let theirs = overlap.shared.map {
            MeetingMath.rangeLabel(start: $0.start, end: $0.end, zone: store.theirZone, day: store.day)
        }.joined(separator: ", ")

        return ("\(yours) your time", "\(theirs) \(store.theirCity.city)")
    }

    private func copy(_ line: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(line, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            copied = false
        }
    }

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

private struct OverlapBar: View {
    var quarters: [QuarterMark]

    var body: some View {
        Canvas { context, size in
            guard !quarters.isEmpty else { return }
            let width = size.width / CGFloat(quarters.count)
            for (index, quarter) in quarters.enumerated() {
                let rect = CGRect(
                    x: CGFloat(index) * width,
                    y: 0,
                    width: width + 0.6,
                    height: size.height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 0), with: .color(fill(quarter)))
            }
        }
        .background(Theme.track)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel("Shared working hours across your day")
    }

    private func fill(_ quarter: QuarterMark) -> Color {
        switch (quarter.you, quarter.them) {
        case (true, true): Theme.client
        case (true, false): Theme.you.opacity(0.55)
        case (false, true): Theme.client.opacity(0.40)
        case (false, false): Theme.track
        }
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
