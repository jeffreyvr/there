import AppKit
import SwiftUI
import ThereCore

@MainActor
enum Snapshot {
    static func write(store: ClockStore, path: String) {
        let frames: [(String, NSAppearance.Name)] = [
            ("light", .aqua),
            ("dark", .darkAqua),
        ]

        for (name, appearanceName) in frames {
            guard let appearance = NSAppearance(named: appearanceName) else { continue }
            let image = render(store: store, appearance: appearance)
            let url = URL(fileURLWithPath: "\(path)-\(name).png")
            guard let data = pngData(from: image) else {
                fputs("Could not render \(url.path)\n", stderr)
                continue
            }
            do {
                try data.write(to: url)
                fputs("Wrote \(url.path)\n", stderr)
            } catch {
                fputs("Could not write \(url.path): \(error)\n", stderr)
            }
        }
    }

    private static func render(store: ClockStore, appearance: NSAppearance) -> NSImage {
        let root = PopoverView()
            .environment(store)
        let host = NSHostingView(rootView: root)
        host.appearance = appearance
        host.frame = CGRect(x: 0, y: 0, width: 360, height: 900)

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.contentView = host
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()

        let height = min(max(host.fittingSize.height, 280), 900)
        let size = CGSize(width: 360, height: height)
        host.frame.size = size
        window.setContentSize(size)
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()

        let image = NSImage(size: size)
        image.lockFocus()
        if let context = NSGraphicsContext.current {
            host.displayIgnoringOpacity(host.bounds, in: context)
        }
        image.unlockFocus()
        return image
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
