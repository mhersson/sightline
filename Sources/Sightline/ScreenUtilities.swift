import AppKit
@preconcurrency import ScreenCaptureKit

// MARK: - Screen Matching Utilities

extension SCDisplay {
    /// Find the matching NSScreen for this SCDisplay
    func matchingNSScreen() -> NSScreen? {
        let scFrame = CGRect(
            x: CGFloat(frame.origin.x),
            y: CGFloat(frame.origin.y),
            width: CGFloat(width),
            height: CGFloat(height)
        )
        return NSScreen.screens.first { $0.frame == scFrame }
    }
}

extension NSScreen {
    /// Find the matching SCDisplay from a list of displays
    func matchingSCDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        displays.first { display in
            let scFrame = CGRect(
                x: CGFloat(display.frame.origin.x),
                y: CGFloat(display.frame.origin.y),
                width: CGFloat(display.width),
                height: CGFloat(display.height)
            )
            return scFrame == self.frame
        }
    }
}

// MARK: - Coordinate Conversion Utilities

extension CGRect {
    /// Convert from screen-local coordinates to global coordinates
    func toGlobalCoordinates(relativeTo screen: NSScreen) -> CGRect {
        CGRect(
            x: origin.x + screen.frame.origin.x,
            y: origin.y + screen.frame.origin.y,
            width: width,
            height: height
        )
    }

    /// Convert from global coordinates to screen-local coordinates
    func toLocalCoordinates(relativeTo screen: NSScreen) -> CGRect {
        CGRect(
            x: origin.x - screen.frame.origin.x,
            y: origin.y - screen.frame.origin.y,
            width: width,
            height: height
        )
    }

    /// Convert from AppKit coordinates (bottom-left origin) to ScreenCaptureKit coordinates (top-left origin)
    /// The screen parameter should be the NSScreen this rect is relative to (in local coordinates)
    func flippedForScreenCapture(screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: origin.x,
            y: screenHeight - origin.y - height,
            width: width,
            height: height
        )
    }
}
