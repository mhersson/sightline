import AppKit

struct Selection: Sendable {
    /// The selected region in global AppKit coordinates (bottom-left origin).
    let rect: CGRect
    let screenFrame: CGRect
    let displayID: CGDirectDisplayID
}

/// Dims every screen and lets the user drag out a rectangle on one of them.
/// Single use: create one per selection.
@MainActor
final class SelectionOverlay {
    private var windows: [OverlayWindow] = []
    private var startPoint: CGPoint = .zero
    private var startScreen: NSScreen?
    private var selectionRect: CGRect = .zero
    private var continuation: CheckedContinuation<Selection?, Never>?

    /// Returns the selected region, or nil if the user pressed Escape or the drag was too small.
    func run() async -> Selection? {
        windows = NSScreen.screens.map { OverlayWindow(screen: $0, controller: self) }

        // Become a regular, active app while the overlay is up so it gets key events (Escape).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let mouseLocation = NSEvent.mouseLocation
        for window in windows {
            window.orderFrontRegardless()
            if window.frame.contains(mouseLocation) {
                window.makeKey()
            }
            window.invalidateCursorRects(for: window.selectionView)
        }
        NSCursor.crosshair.set()

        return await withCheckedContinuation { continuation = $0 }
    }

    fileprivate func mouseDown(at screenPoint: CGPoint, in window: OverlayWindow) {
        startPoint = screenPoint
        startScreen = window.targetScreen
        selectionRect = .zero
        updateViews()
    }

    fileprivate func mouseDragged(to screenPoint: CGPoint) {
        guard let bounds = startScreen?.frame else { return }

        // Keep the selection on the screen where the drag started.
        let x = min(max(screenPoint.x, bounds.minX), bounds.maxX)
        let y = min(max(screenPoint.y, bounds.minY), bounds.maxY)
        selectionRect = CGRect(
            x: min(startPoint.x, x),
            y: min(startPoint.y, y),
            width: abs(x - startPoint.x),
            height: abs(y - startPoint.y)
        )
        updateViews()
    }

    fileprivate func mouseUp() {
        guard let startScreen, let displayID = startScreen.displayID,
              selectionRect.width >= 10, selectionRect.height >= 10 else {
            finish(with: nil)
            return
        }
        finish(with: Selection(rect: selectionRect, screenFrame: startScreen.frame, displayID: displayID))
    }

    fileprivate func cancel() {
        finish(with: nil)
    }

    private func updateViews() {
        for window in windows {
            window.selectionView.selectionRect = window.convertFromScreen(selectionRect)
            window.selectionView.needsDisplay = true
        }
    }

    private func finish(with selection: Selection?) {
        guard let continuation else { return }
        self.continuation = nil

        windows.forEach { $0.orderOut(nil) }
        NSApp.setActivationPolicy(.accessory)
        NSCursor.arrow.set()
        Log.debug("SelectionOverlay: finished with \(selection.map { "\($0.rect)" } ?? "no selection")")
        continuation.resume(returning: selection)
    }
}

/// One borderless overlay per screen.
private final class OverlayWindow: NSWindow {
    let targetScreen: NSScreen
    let selectionView: SelectionView
    private weak var controller: SelectionOverlay?

    init(screen: NSScreen, controller: SelectionOverlay) {
        self.targetScreen = screen
        self.controller = controller
        self.selectionView = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))

        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)

        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false  // explicit, so the cleared selection area doesn't pass clicks through
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        controller?.mouseDown(at: convertPoint(toScreen: event.locationInWindow), in: self)
    }

    override func mouseDragged(with event: NSEvent) {
        controller?.mouseDragged(to: convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseUp(with event: NSEvent) {
        controller?.mouseUp()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Escape
            controller?.cancel()
        }
    }
}

private final class SelectionView: NSView {
    var selectionRect: CGRect = .zero
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .cursorUpdate],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        guard !selectionRect.isEmpty, selectionRect.intersects(bounds) else { return }

        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        NSColor.white.setStroke()
        let border = NSBezierPath(rect: selectionRect.insetBy(dx: -1, dy: -1))
        border.lineWidth = 2
        border.stroke()

        let label = "\(Int(selectionRect.width.rounded())) × \(Int(selectionRect.height.rounded()))"
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .backgroundColor: NSColor.black.withAlphaComponent(0.7),
        ]
        let size = label.size(withAttributes: attributes)
        // Above the selection, but kept on screen when the selection touches the top edge.
        let origin = CGPoint(
            x: selectionRect.midX - size.width / 2,
            y: min(selectionRect.maxY + 8, bounds.maxY - size.height - 4)
        )
        label.draw(at: origin, withAttributes: attributes)
    }
}
