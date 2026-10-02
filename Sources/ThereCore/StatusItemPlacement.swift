import CoreGraphics

public enum StatusItemPlacement {
    /// Hidden Bar parks items far past the left edge of every screen.
    /// Only the horizontal position counts: an auto-hidden menu bar moves items above the screen,
    /// and they come back when the user moves the pointer to the top.
    public static func isReachable(itemFrame: CGRect, screenFrames: [CGRect]) -> Bool {
        guard itemFrame.width > 1 else { return false }
        return screenFrames.contains { screen in
            itemFrame.maxX > screen.minX && itemFrame.minX < screen.maxX
        }
    }
}
