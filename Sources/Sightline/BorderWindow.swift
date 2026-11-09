import AppKit

/// Outlines the captured region on screen. Excluded from the capture itself.
final class BorderWindow: NSWindow {
    /// - Parameter frame: The captured region in global AppKit coordinates.
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)

        // Normal level so the border doesn't draw over windows that overlap the edge of the region.
        level = .normal
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = BorderView(frame: CGRect(origin: .zero, size: frame.size))
    }
}

private final class BorderView: NSView {
    private static let color = NSColor(red: 0.902, green: 0.596, blue: 0.459, alpha: 1.0)  // #E69875

    override func draw(_ dirtyRect: NSRect) {
        Self.color.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        path.lineWidth = 2
        path.stroke()
    }
}
