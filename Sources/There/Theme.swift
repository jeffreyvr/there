import AppKit
import SwiftUI
import ThereCore

enum Theme {
    static let paper = color(light: rgb(0.973, 0.961, 0.937), dark: rgb(0.102, 0.098, 0.090))
    static let you = color(light: rgb(0.58, 0.30, 0.13), dark: rgb(0.90, 0.66, 0.44))
    static let client = color(light: rgb(0.06, 0.38, 0.36), dark: rgb(0.49, 0.81, 0.75))
    static let good = color(light: rgb(0.12, 0.42, 0.28), dark: rgb(0.55, 0.82, 0.66))
    static let mixed = color(light: rgb(0.52, 0.34, 0.08), dark: rgb(0.91, 0.74, 0.42))
    static let bad = color(light: rgb(0.55, 0.18, 0.15), dark: rgb(0.91, 0.55, 0.50))
    static let track = color(light: rgb(0.90, 0.88, 0.84), dark: rgb(0.20, 0.19, 0.17))

    static func tone(_ tone: Verdict.Tone) -> Color {
        switch tone {
        case .good: good
        case .mixed: mixed
        case .bad: bad
        }
    }

    private static func color(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
