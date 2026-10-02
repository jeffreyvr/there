import SwiftUI
import ThereCore

enum ZoneTarget {
    case you
    case client

    var title: String {
        switch self {
        case .you: "Your City"
        case .client: "Client City"
        }
    }
}

struct CityPicker: View {
    var target: ZoneTarget
    var currentID: String
    var followsMac: Bool
    var onPick: (String) -> Void
    var onUseMac: () -> Void
    var onClose: () -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            searchField

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if isBrowsing {
                        if target == .you {
                            macRow
                            Divider()
                                .padding(.horizontal, Theme.inset)
                                .padding(.vertical, 4)
                        }

                        Text("Places You Use")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Theme.inset)
                            .padding(.vertical, 4)
                    }

                    ForEach(Cities.search(query)) { zone in
                        Button {
                            onPick(zone.identifier)
                        } label: {
                            row(title: zone.city, subtitle: subtitle(zone), selected: isSelected(zone))
                        }
                        .buttonStyle(.row)
                    }
                }
            }
            .frame(height: 360)
        }
        .padding(6)
        .frame(width: 320)
        .onAppear {
            searchFocused = true
        }
        .onExitCommand(perform: onClose)
    }

    private var isBrowsing: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .help("Back")

            Text(target.title)
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.primary.opacity(0.05), in: .capsule)
        .padding(.horizontal, 4)
    }

    private var macRow: some View {
        Button(action: onUseMac) {
            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                row(
                    title: "This Mac",
                    subtitle: Cities.choice(for: TimeZone.current.identifier).city,
                    selected: followsMac
                )
            }
        }
        .buttonStyle(.row)
    }

    private func row(title: String, subtitle: String, selected: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
    }

    private func isSelected(_ zone: ZoneChoice) -> Bool {
        zone.identifier == currentID && (target == .client || !followsMac)
    }

    private func subtitle(_ zone: ZoneChoice) -> String {
        let offset = TimeZone(identifier: zone.identifier).map { MeetingMath.offsetLabel($0, at: .now) } ?? ""
        if let code = zone.code {
            return "\(code) · \(offset)"
        }
        return "\(zone.region) · \(offset)"
    }
}
