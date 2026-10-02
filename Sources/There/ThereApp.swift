import AppKit
import SwiftUI
import ThereCore

@main
struct ThereApp: App {
    @NSApplicationDelegateAdaptor(AppModel.self) private var model
    @State private var store: ClockStore

    init() {
        let store = ClockStore(defaults: Launch.defaults())
        store.apply(Launch.overrides)
        _store = State(initialValue: store)
        AppRuntime.store = store
    }

    var body: some Scene {
        // A hidden window scene keeps launch from crashing. The menu bar is the app.
        WindowGroup(id: "main") {
            PopoverView()
                .environment(store)
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}

@MainActor
enum AppRuntime {
    static var store: ClockStore?
}

final class AppModel: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard let store = AppRuntime.store else { return }
            Launch.finish(store: store)
            if Launch.snapshotPath == nil {
                let statusBar = StatusBarController(store: store)
                self.statusBar = statusBar
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    MainActor.assumeIsolated {
                        self.hidePanels(except: nil)
                    }
                }
                statusBar.whenHidden {
                    self.presentPanel(store: store)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor
    private func presentPanel(store: ClockStore) {
        NSApp.setActivationPolicy(.regular)
        hidePanels(except: nil)
        PreviewWindow.show(store: store)
        NSApp.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            MainActor.assumeIsolated {
                NSApp.windows.first { $0.title == "There" }?.makeKeyAndOrderFront(nil)
                NSApp.activate()
            }
        }
    }

    @MainActor
    private func hidePanels(except kept: NSWindow?) {
        for window in NSApp.windows where window !== kept && window.canBecomeMain && window.level == .normal {
            window.orderOut(nil)
        }
    }
}

enum Launch {
    private static let options = parse()
    static var showsWindow: Bool { options.showsWindow }
    static var snapshotPath: String? { options.snapshotPath }
    static var overrides: LaunchOverrides { options.overrides }

    static func defaults() -> UserDefaults {
        let preview = snapshotPath != nil || overrides.yourZoneID != nil || overrides.clientZoneID != nil
        guard preview else { return .standard }
        let suite = UserDefaults(suiteName: "nl.vanrossum.there.preview")!
        suite.removePersistentDomain(forName: "nl.vanrossum.there.preview")
        return suite
    }

    @MainActor
    static func finish(store: ClockStore) {
        guard let snapshotPath else { return }
        if showsWindow {
            PreviewWindow.show(store: store)
        }
        Snapshot.write(store: store, path: snapshotPath)
        NSApp.terminate(nil)
    }

    private struct Options {
        var showsWindow = false
        var snapshotPath: String?
        var overrides = LaunchOverrides()
    }

    private static func parse() -> Options {
        var options = Options()
        let args = Array(CommandLine.arguments.dropFirst())
        var index = 0

        func value() -> String? {
            guard index + 1 < args.count else { return nil }
            index += 1
            return args[index]
        }

        while index < args.count {
            switch args[index] {
            case "--window":
                options.showsWindow = true
            case "--snapshot":
                options.snapshotPath = value()
            case "--you":
                options.overrides.yourZoneID = value()
            case "--client":
                options.overrides.clientZoneID = value()
            case "--time":
                options.overrides.timeText = value()
            case "--side":
                options.overrides.side = value() == "mine" ? .mine : .theirs
            case "--day":
                options.overrides.day = value().flatMap(civilDay)
            default:
                break
            }
            index += 1
        }

        return options
    }

    private static func civilDay(_ text: String) -> CivilDay? {
        let parts = text.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        return CivilDay(year: year, month: month, day: day)
    }
}

@MainActor
enum PreviewWindow {
    static func show(store: ClockStore) {
        let host = NSHostingView(
            rootView: PopoverView()
                .environment(store)
                .environment(\.menuItemHidden, true)
        )
        host.frame = CGRect(x: 0, y: 0, width: 360, height: 800)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "There"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentView = host
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: host.fittingSize.width, height: min(host.fittingSize.height, 900)))
        window.center()
        window.makeKeyAndOrderFront(nil)
        retained = window
    }

    private static var retained: NSWindow?
}
