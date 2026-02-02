import AppKit
@preconcurrency import ScreenCaptureKit

struct ScreenSelection: Sendable {
    let rect: CGRect
    let screen: SCDisplay
}

@MainActor
final class SelectionOverlayController {
    private var overlayWindows: [OverlayWindow] = []
    private var selectionRect: CGRect = .zero
    private var startPoint: CGPoint = .zero  // In global screen coordinates
    private var currentScreen: NSScreen?
    private var continuation: CheckedContinuation<ScreenSelection?, Never>?
    private var continuationConsumed = false

    func waitForSelection() async -> ScreenSelection? {
        Log.debug("SelectionOverlay: waitForSelection called")

        // Reset state
        continuationConsumed = false
        selectionRect = .zero
        startPoint = .zero
        currentScreen = nil

        // Create one overlay window per screen
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()

        for (i, screen) in NSScreen.screens.enumerated() {
            Log.debug("Screen \(i): frame=\(screen.frame)")
            let window = OverlayWindow(screen: screen, controller: self)
            overlayWindows.append(window)
        }

        // Force app to front and active
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Show all windows
        for window in overlayWindows {
            window.setIsVisible(true)
            window.orderFrontRegardless()
        }

        // Make the first window key (it will receive events)
        overlayWindows.first?.makeKey()

        // Set crosshair cursor on all windows
        for window in overlayWindows {
            window.invalidateCursorRects(for: window.selectionView)
        }
        NSCursor.crosshair.set()

        Log.debug("SelectionOverlay: waiting for continuation")
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    fileprivate func handleMouseDown(at windowPoint: CGPoint, in window: OverlayWindow) {
        // Convert to global screen coordinates
        startPoint = CGPoint(
            x: windowPoint.x + window.frame.origin.x,
            y: windowPoint.y + window.frame.origin.y
        )
        currentScreen = NSScreen.screens.first { $0.frame.contains(startPoint) }
        Log.debug("handleMouseDown: startPoint=\(startPoint), currentScreen=\(String(describing: currentScreen?.frame))")
        selectionRect = .zero
        updateAllViews()
    }

    fileprivate func handleMouseDragged(to windowPoint: CGPoint, in window: OverlayWindow) {
        // Convert to global screen coordinates
        var globalCurrent = CGPoint(
            x: windowPoint.x + window.frame.origin.x,
            y: windowPoint.y + window.frame.origin.y
        )

        // Constrain to the starting screen
        if let screen = currentScreen {
            globalCurrent.x = max(screen.frame.minX, min(globalCurrent.x, screen.frame.maxX))
            globalCurrent.y = max(screen.frame.minY, min(globalCurrent.y, screen.frame.maxY))
        }

        selectionRect = CGRect(
            x: min(startPoint.x, globalCurrent.x),
            y: min(startPoint.y, globalCurrent.y),
            width: abs(globalCurrent.x - startPoint.x),
            height: abs(globalCurrent.y - startPoint.y)
        )

        updateAllViews()
    }

    fileprivate func handleMouseUp() {
        hideAllWindows()

        guard selectionRect.width >= 10, selectionRect.height >= 10 else {
            resumeContinuation(with: nil)
            return
        }

        Task {
            let selection = await findSCDisplay()
            resumeContinuation(with: selection)
        }
    }

    fileprivate func handleEscape() {
        hideAllWindows()
        resumeContinuation(with: nil)
    }

    private func updateAllViews() {
        for window in overlayWindows {
            // Convert global selectionRect to window-local coordinates
            let localRect = CGRect(
                x: selectionRect.origin.x - window.frame.origin.x,
                y: selectionRect.origin.y - window.frame.origin.y,
                width: selectionRect.width,
                height: selectionRect.height
            )
            window.selectionView.selectionRect = localRect
            window.selectionView.needsDisplay = true
        }
    }

    private func hideAllWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
    }

    private func cleanup() {
        NSApp.setActivationPolicy(.accessory)
        NSCursor.arrow.set()
    }

    private func resumeContinuation(with result: ScreenSelection?) {
        Log.debug("SelectionOverlay: resumeContinuation called, consumed=\(continuationConsumed)")
        guard !continuationConsumed else { return }
        continuationConsumed = true
        cleanup()
        continuation?.resume(returning: result)
        continuation = nil
    }

    private func findSCDisplay() async -> ScreenSelection? {
        Log.debug("findSCDisplay: currentScreen=\(String(describing: currentScreen?.frame))")
        guard let nsScreen = currentScreen else {
            Log.debug("findSCDisplay: no currentScreen set")
            return nil
        }

        do {
            let content = try await SCShareableContent.current
            Log.debug("findSCDisplay: found \(content.displays.count) displays")
            for (i, display) in content.displays.enumerated() {
                Log.debug("  SCDisplay \(i): frame=(\(display.frame.origin.x), \(display.frame.origin.y), \(display.width), \(display.height))")
            }

            guard let scDisplay = nsScreen.matchingSCDisplay(from: content.displays) else {
                Log.debug("findSCDisplay: Could not find matching SCDisplay for screen \(nsScreen.frame)")
                return nil
            }

            // selectionRect is already in global coordinates
            Log.debug("findSCDisplay: selectionRect (global)=\(selectionRect)")

            // Convert to screen-local coordinates
            let localRect = selectionRect.toLocalCoordinates(relativeTo: nsScreen)
            Log.debug("findSCDisplay: localRect=\(localRect)")

            // Flip Y coordinate: AppKit uses bottom-left origin, ScreenCaptureKit uses top-left
            let flippedRect = localRect.flippedForScreenCapture(screenHeight: nsScreen.frame.height)
            Log.debug("findSCDisplay: flippedRect=\(flippedRect)")

            return ScreenSelection(rect: flippedRect, screen: scDisplay)
        } catch {
            Log.debug("Failed to get shareable content: \(error)")
        }
        return nil
    }
}

// Individual overlay window for each screen
private final class OverlayWindow: NSWindow {
    let selectionView: SelectionView
    weak var controller: SelectionOverlayController?

    init(screen: NSScreen, controller: SelectionOverlayController) {
        self.controller = controller
        self.selectionView = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        selectionView.autoresizingMask = [.width, .height]
        contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        controller?.handleMouseDown(at: event.locationInWindow, in: self)
    }

    override func mouseDragged(with event: NSEvent) {
        controller?.handleMouseDragged(to: event.locationInWindow, in: self)
    }

    override func mouseUp(with event: NSEvent) {
        controller?.handleMouseUp()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            controller?.handleEscape()
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
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
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
        // Dim overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        guard selectionRect.width > 0, selectionRect.height > 0 else { return }

        // Only draw selection if it intersects this view's bounds
        let intersection = selectionRect.intersection(bounds)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return }

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

// Backwards compatibility alias
typealias SelectionOverlay = SelectionOverlayController
