import SwiftUI
import ThereCore

enum ZoneTarget {
    case you
    case client

    var title: String {
        switch self {
        case .you: "You"
        case .client: "Client"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text(target.title)
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                Spacer()
            }

            TextField("Search cities", text: $query)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if target == .you, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        macRow
                    }

                    if query.isEmpty {
                        Text("Places you use. Search for any city.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                    }

                    ForEach(Cities.search(query)) { zone in
                        Button {
                            onPick(zone.identifier)
                        } label: {
                            zoneRow(zone)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 340)
        }
        .padding(18)
        .frame(width: 360)
        .background(Theme.paper)
    }

    private var macRow: some View {
        Button(action: onUseMac) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("This Mac")
                        .font(.system(size: 13, weight: followsMac ? .semibold : .regular))
                    Text(Cities.choice(for: TimeZone.current.identifier).city)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if followsMac {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.you)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(followsMac ? Theme.you.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func zoneRow(_ zone: ZoneChoice) -> some View {
        let selected = zone.identifier == currentID && (target == .client || !followsMac)
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(zone.city)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                Text(subtitle(zone))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(target == .you ? Theme.you : Theme.client)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? (target == .you ? Theme.you : Theme.client).opacity(0.10) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func subtitle(_ zone: ZoneChoice) -> String {
        let offset = TimeZone(identifier: zone.identifier).map { MeetingMath.offsetLabel($0, at: .now) } ?? ""
        if let code = zone.code {
            return "\(code) · \(offset)"
        }
        return "\(zone.region) · \(offset)"
    }
}
