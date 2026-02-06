import AppKit
@preconcurrency import ScreenCaptureKit

// MARK: - Screen Matching Utilities

extension SCDisplay {
    /// Find the matching NSScreen for this SCDisplay using display IDs
    func matchingNSScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return screenNumber == displayID
        }
    }
}

extension NSScreen {
    /// Find the matching SCDisplay from a list of displays using display IDs
    func matchingSCDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return displays.first { $0.displayID == screenNumber }
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
