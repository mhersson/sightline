import AppKit
@preconcurrency import ScreenCaptureKit

struct ScreenSelection: Sendable {
    let rect: CGRect
    let screen: SCDisplay
}

@MainActor
final class SelectionOverlay: NSWindow {
    private var selectionRect: CGRect = .zero
    private var startPoint: CGPoint = .zero
    private var currentScreen: NSScreen?
    private var continuation: CheckedContinuation<ScreenSelection?, Never>?
    private var continuationConsumed = false
    private var selectionView: SelectionView?

    init() {
        // Span all screens
        let fullFrame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }

        super.init(
            contentRect: fullFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Use popUpMenu level - high enough to be above most windows but still interactive
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let view = SelectionView(frame: fullFrame)
        view.autoresizingMask = [.width, .height]
        contentView = view
        selectionView = view
    }

    // Required for borderless windows to receive key events
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func waitForSelection() async -> ScreenSelection? {
        Log.debug("SelectionOverlay: waitForSelection called, isVisible=\(isVisible)")

        // Reset all state
        continuationConsumed = false
        selectionRect = .zero
        startPoint = .zero
        currentScreen = nil
        selectionView?.selectionRect = .zero

        // Recalculate frame in case screens changed
        let fullFrame = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
        setFrame(fullFrame, display: false)
        selectionView?.frame = CGRect(origin: .zero, size: fullFrame.size)
        selectionView?.needsDisplay = true

        // Force app to front and active
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Show and focus window
        Log.debug("SelectionOverlay: showing window at frame \(frame)")
        setIsVisible(true)
        orderFrontRegardless()
        makeKey()

        // Set crosshair cursor
        selectionView?.window?.invalidateCursorRects(for: selectionView!)
        NSCursor.crosshair.set()

        Log.debug("SelectionOverlay: waiting for continuation")
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    private func cleanup() {
        // Restore accessory policy so app doesn't appear in dock
        NSApp.setActivationPolicy(.accessory)
        NSCursor.arrow.set()
    }

    private func resumeContinuation(with result: ScreenSelection?) {
        Log.debug("SelectionOverlay: resumeContinuation called, consumed=\(continuationConsumed), result=\(String(describing: result))")
        guard !continuationConsumed else { return }
        continuationConsumed = true
        cleanup()
        continuation?.resume(returning: result)
        continuation = nil
        Log.debug("SelectionOverlay: continuation resumed")
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentScreen = NSScreen.screens.first { $0.frame.contains(startPoint) }
        selectionRect = .zero
        selectionView?.selectionRect = .zero
        selectionView?.needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        var current = event.locationInWindow

        // Constrain to the starting screen
        if let screen = currentScreen {
            current.x = max(screen.frame.minX, min(current.x, screen.frame.maxX))
            current.y = max(screen.frame.minY, min(current.y, screen.frame.maxY))
        }

        selectionRect = CGRect(
            x: min(startPoint.x, current.x),
            y: min(startPoint.y, current.y),
            width: abs(current.x - startPoint.x),
            height: abs(current.y - startPoint.y)
        )

        selectionView?.selectionRect = selectionRect
        selectionView?.needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        orderOut(nil)

        guard selectionRect.width >= 10, selectionRect.height >= 10 else {
            resumeContinuation(with: nil)
            return
        }

        Task {
            let selection = await findSCDisplay()
            resumeContinuation(with: selection)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            orderOut(nil)
            resumeContinuation(with: nil)
        }
    }

    private func findSCDisplay() async -> ScreenSelection? {
        guard let nsScreen = currentScreen else { return nil }

        do {
            let content = try await SCShareableContent.current

            guard let scDisplay = nsScreen.matchingSCDisplay(from: content.displays) else {
                Log.debug("Could not find matching SCDisplay for screen")
                return nil
            }

            // Convert selection rect to screen-local coordinates
            let localRect = selectionRect.toLocalCoordinates(relativeTo: nsScreen)

            // Flip Y coordinate: AppKit uses bottom-left origin, ScreenCaptureKit uses top-left
            let flippedRect = localRect.flippedForScreenCapture(screenHeight: nsScreen.frame.height)

            return ScreenSelection(rect: flippedRect, screen: scDisplay)
        } catch {
            Log.debug("Failed to get shareable content: \(error)")
        }
        return nil
    }
}

private final class SelectionView: NSView {
    var selectionRect: CGRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Dim overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        guard selectionRect.width > 0, selectionRect.height > 0 else { return }

        // Clear the selection area
        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        // Draw border around selection
        NSColor.white.setStroke()
        let borderPath = NSBezierPath(rect: selectionRect.insetBy(dx: -1, dy: -1))
        borderPath.lineWidth = 2
        borderPath.stroke()

        // Draw dimensions label
        let dimensions = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let size = dimensions.size(withAttributes: attrs)
        let labelPoint = CGPoint(
            x: selectionRect.midX - size.width / 2,
            y: selectionRect.maxY + 8
        )
        dimensions.draw(at: labelPoint, withAttributes: attrs)
    }
}
