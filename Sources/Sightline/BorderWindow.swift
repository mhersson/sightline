import AppKit

@MainActor
final class BorderWindow: NSWindow {
    init(frame: CGRect, on screen: NSScreen) {
        let globalFrame = frame.toGlobalCoordinates(relativeTo: screen)

        super.init(
            contentRect: globalFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let borderView = BorderView(frame: CGRect(origin: .zero, size: globalFrame.size))
        borderView.autoresizingMask = [.width, .height]
        contentView = borderView
    }

    func updateFrame(_ frame: CGRect, on screen: NSScreen) {
        let globalFrame = frame.toGlobalCoordinates(relativeTo: screen)
        setFrame(globalFrame, display: true)
    }
}

private final class BorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // Everforest orange: #E69875
        let borderColor = NSColor(red: 0.902, green: 0.596, blue: 0.459, alpha: 1.0)
        borderColor.setStroke()

        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        borderPath.lineWidth = 2
        borderPath.stroke()
    }
}
