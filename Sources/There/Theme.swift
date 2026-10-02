import SwiftUI
import ThereCore

enum Theme {
    /// Rows add their own hover inset, so plain content needs the same inset to line up.
    static let inset: CGFloat = 10

    static func tone(_ tone: Verdict.Tone) -> Color {
        switch tone {
        case .good: .green
        case .mixed: .orange
        case .bad: .red
        }
    }
}

/// A full-width row that highlights on hover, like an item in a menu bar menu.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private struct Row: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, Theme.inset)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .background(highlight, in: .rect(cornerRadius: 7, style: .continuous))
                .onHover { hovering = $0 }
        }

        private var highlight: Color {
            if configuration.isPressed { return .primary.opacity(0.12) }
            return hovering ? .primary.opacity(0.06) : .clear
        }
    }
}

extension ButtonStyle where Self == RowButtonStyle {
    static var row: RowButtonStyle { RowButtonStyle() }
}
