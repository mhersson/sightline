import AppKit
import IOSurface
import QuartzCore

/// A window that displays the captured screen region
/// Users share this window directly in video conferencing apps
final class CaptureWindow: NSWindow {
    private let renderView: RenderView

    init(width: Int, height: Int) {
        renderView = RenderView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Set window properties
        title = "Sightline Capture"
        contentView = renderView
        backgroundColor = .black
        isOpaque = true

        // Position window in center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - CGFloat(width) / 2
            let y = screenFrame.midY - CGFloat(height) / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Standard window level so it appears in window sharing pickers
        level = .normal
        collectionBehavior = [.fullScreenAuxiliary]

        Log.debug("CaptureWindow: created \(width)x\(height)")
    }

    func updateSurface(_ surface: IOSurface) {
        renderView.updateSurface(surface)
    }

    /// Called when window is closed via the close button
    override func close() {
        // Notify that capture should stop
        NotificationCenter.default.post(name: .captureWindowClosed, object: nil)
        super.close()
    }
}

/// View that renders an IOSurface by converting to CGImage
private class RenderView: NSView {
    private var imageLayer: CALayer?
    private var frameCount = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        // Create the image layer
        let newLayer = CALayer()
        newLayer.frame = bounds
        newLayer.contentsGravity = .resizeAspect
        newLayer.isOpaque = true
        newLayer.drawsAsynchronously = true
        layer?.addSublayer(newLayer)
        imageLayer = newLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        imageLayer?.frame = bounds
    }

    func updateSurface(_ surface: IOSurface) {
        frameCount += 1

        // Log every 60 frames (~2 seconds)
        if frameCount % 60 == 0 {
            Log.debug("RenderView: frame #\(frameCount)")
        }

        // Create a CGImage from the IOSurface
        let width = IOSurfaceGetWidth(surface)
        let height = IOSurfaceGetHeight(surface)

        // Lock surface for reading
        IOSurfaceLock(surface, .readOnly, nil)

        let baseAddress = IOSurfaceGetBaseAddress(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)

        // Create CGImage from the surface data
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ),
              let cgImage = context.makeImage() else {
            IOSurfaceUnlock(surface, .readOnly, nil)
            return
        }

        // Update layer while surface is still locked
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer?.contents = cgImage
        CATransaction.commit()

        // Only unlock AFTER CA has the contents
        IOSurfaceUnlock(surface, .readOnly, nil)
    }
}

// MARK: - Notification for window close

extension Notification.Name {
    static let captureWindowClosed = Notification.Name("captureWindowClosed")
}
