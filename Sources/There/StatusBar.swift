import AppKit
import SwiftUI
import ThereCore

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let host: NSViewController
    private var placementChecks = 0
    private var placementTimer: Timer?
    private var onHidden: (@MainActor () -> Void)?

    init(store: ClockStore) {
        let host = NSHostingController(rootView: PopoverView().environment(store))
        host.sizingOptions = .preferredContentSize
        self.host = host
        super.init()

        let button = item.button
        button?.font = .systemFont(ofSize: 13, weight: .semibold)
        button?.title = " There"
        button?.image = nil
        button?.toolTip = "There"
        button?.target = self
        button?.action = #selector(toggle)
        item.autosaveName = "There"
        item.isVisible = true

        popover.contentViewController = host
        popover.behavior = .transient
        popover.delegate = self
    }

    var isOnScreen: Bool {
        guard let frame = item.button?.window?.frame else { return false }
        return StatusItemPlacement.isReachable(itemFrame: frame, screenFrames: NSScreen.screens.map(\.frame))
    }

    /// Calls `show` once the status item has settled off screen. Items often appear, then Hidden Bar moves them.
    func whenHidden(_ show: @escaping @MainActor () -> Void) {
        onHidden = show
        placementChecks = 0
        placementTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.notePlacement()
            }
        }
    }

    private func notePlacement() {
        placementChecks += 1
        let hidden = !isOnScreen && placementChecks >= 3
        let stayedVisible = isOnScreen && placementChecks >= 8
        guard hidden || stayedVisible else { return }
        placementTimer?.invalidate()
        placementTimer = nil
        guard hidden else { return }
        onHidden?()
        onHidden = nil
    }

    @objc func toggle() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        item.button?.highlight(false)
    }

    private func showPopover() {
        guard let button = item.button else { return }
        host.view.layoutSubtreeIfNeeded()
        let height = min(max(host.view.fittingSize.height, 480), 900)
        popover.contentSize = NSSize(width: 360, height: height)
        button.highlight(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
