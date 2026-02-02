import AppKit
@preconcurrency import ScreenCaptureKit

// MARK: - Screen Matching Utilities

extension SCDisplay {
    /// Find the matching NSScreen for this SCDisplay
    /// Note: NSScreen and SCDisplay may have different y coordinates due to different coordinate systems,
    /// so we match based on x origin, width, and height only
    func matchingNSScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            let sameX = CGFloat(frame.origin.x) == screen.frame.origin.x
            let sameWidth = CGFloat(width) == screen.frame.width
            let sameHeight = CGFloat(height) == screen.frame.height
            return sameX && sameWidth && sameHeight
        }
    }
}

extension NSScreen {
    /// Find the matching SCDisplay from a list of displays
    /// Note: NSScreen and SCDisplay may have different y coordinates due to different coordinate systems,
    /// so we match based on x origin, width, and height only
    func matchingSCDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        displays.first { display in
            let sameX = CGFloat(display.frame.origin.x) == self.frame.origin.x
            let sameWidth = CGFloat(display.width) == self.frame.width
            let sameHeight = CGFloat(display.height) == self.frame.height
            return sameX && sameWidth && sameHeight
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
