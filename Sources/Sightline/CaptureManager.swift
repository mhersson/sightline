import AppKit
import ScreenCaptureKit

@MainActor
final class CaptureManager: NSObject {
    /// Called whenever `isCapturing` changes, including when capture stops on its own
    /// (window closed, display unplugged, stopped from the system menu bar).
    var onStateChange: (() -> Void)?

    private(set) var isCapturing = false {
        didSet {
            if isCapturing != oldValue { onStateChange?() }
        }
    }

    private var stream: SCStream?
    private var captureWindow: CaptureWindow?
    private var borderWindow: BorderWindow?
    private var displayID: CGDirectDisplayID?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func startCapture(_ selection: Selection) async throws {
        let rect = selection.rect
        let screenFrame = selection.screenFrame
        let displayID = selection.displayID
        Log.debug("CaptureManager: starting capture of \(rect) on display \(displayID)")

        // Our windows must be on screen before querying shareable content so they
        // can be excluded from the capture (otherwise: hall-of-mirrors feedback).
        let window = CaptureWindow(contentSize: rect.size)
        window.delegate = self
        window.orderFront(nil)
        captureWindow = window

        let border = BorderWindow(frame: rect)
        border.orderFront(nil)
        borderWindow = border

        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw CaptureError.displayNotFound
            }
            let pid = ProcessInfo.processInfo.processIdentifier
            let ownWindows = content.windows.filter { $0.owningApplication?.processID == pid }
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

            let config = SCStreamConfiguration()
            // sourceRect is in display-local points with a top-left origin;
            // width/height are output pixels, so scale up for Retina displays.
            config.sourceRect = CGRect(
                x: rect.minX - screenFrame.minX,
                y: screenFrame.maxY - rect.maxY,
                width: rect.width,
                height: rect.height
            )
            let scale = CGFloat(filter.pointPixelScale)
            config.width = Int((rect.width * scale).rounded())
            config.height = Int((rect.height * scale).rounded())
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            // The window's layer holds on to the latest surface, so leave headroom in the pool.
            config.queueDepth = 5
            config.showsCursor = true

            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
            try await newStream.startCapture()

            stream = newStream
            self.displayID = displayID
            isCapturing = true
            Log.debug("CaptureManager: streaming \(config.width)x\(config.height) px, excluding \(ownWindows.count) own windows")
        } catch {
            await stopCapture()
            throw error
        }
    }

    func stopCapture() async {
        // Tear down synchronously first so concurrent callers see a stopped state.
        let stoppingStream = stream
        stream = nil
        captureWindow?.orderOut(nil)
        captureWindow = nil
        borderWindow?.orderOut(nil)
        borderWindow = nil
        displayID = nil
        isCapturing = false

        guard let stoppingStream else { return }
        do {
            try await stoppingStream.stopCapture()
            Log.debug("CaptureManager: stream stopped")
        } catch {
            Log.debug("CaptureManager: failed to stop stream: \(error)")
        }
    }

    var isCaptureWindowVisible: Bool {
        captureWindow?.isVisible ?? false
    }

    func showCaptureWindow() {
        guard let captureWindow else { return }
        if captureWindow.isMiniaturized {
            captureWindow.deminiaturize(nil)
        }
        // The app is an inactive accessory app here; plain orderFront would leave it behind other apps.
        captureWindow.orderFrontRegardless()
    }

    func hideCaptureWindow() {
        captureWindow?.orderOut(nil)
    }

    @objc private func screenParametersChanged() {
        guard let displayID, !NSScreen.screens.contains(where: { $0.displayID == displayID }) else { return }
        Log.debug("CaptureManager: captured display disconnected, stopping capture")
        Task { await stopCapture() }
    }
}

// MARK: - NSWindowDelegate

extension CaptureManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        Task { await stopCapture() }
    }
}

// MARK: - SCStreamDelegate

extension CaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Log.debug("CaptureManager: stream stopped with error: \(error)")
        Task { @MainActor in
            await self.stopCapture()
        }
    }
}

// MARK: - SCStreamOutput

// Frames are delivered on the main queue (see `addStreamOutput`), so this conformance can be
// main-actor isolated; @preconcurrency makes Swift verify that at runtime.
extension CaptureManager: @preconcurrency SCStreamOutput {
    /// Hands the frame's IOSurface straight to Core Animation, so no pixels are copied.
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer,
              let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
        else { return }

        captureWindow?.showFrame(surface)
    }
}

// MARK: - Errors

enum CaptureError: LocalizedError {
    case displayNotFound

    var errorDescription: String? {
        switch self {
        case .displayNotFound:
            return "The selected display is no longer available"
        }
    }
}

// MARK: - Helpers

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
