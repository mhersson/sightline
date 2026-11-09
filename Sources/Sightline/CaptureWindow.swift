import AppKit
import QuartzCore

/// Shows the captured region. Users share this window in their video conferencing app.
final class CaptureWindow: NSWindow {
    private let frameLayer = CALayer()

    init(contentSize: CGSize) {
        let contentRect = CGRect(origin: .zero, size: contentSize)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = "Sightline Capture"
        backgroundColor = .black
        collectionBehavior = [.fullScreenAuxiliary]

        frameLayer.frame = contentRect
        frameLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        frameLayer.contentsGravity = .resizeAspect
        frameLayer.actions = ["contents": NSNull()]  // no cross-fade between frames

        let view = NSView(frame: contentRect)
        view.wantsLayer = true
        view.layer?.addSublayer(frameLayer)
        contentView = view

        center()
    }

    func showFrame(_ surface: IOSurface) {
        frameLayer.contents = surface
    }
}
