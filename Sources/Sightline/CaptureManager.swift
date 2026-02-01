import AppKit
@preconcurrency import ScreenCaptureKit
import CoreMedia
import IOSurface
import os.lock

@MainActor
final class CaptureManager: NSObject {
    private(set) var isCapturing = false

    private var captureWindow: CaptureWindow?
    private var stream: SCStream?
    private var borderWindow: BorderWindow?
    private var currentRegion: CGRect = .zero
    private var currentScreen: SCDisplay?
    private var currentNSScreen: NSScreen?
    private var surface: IOSurface?

    // Thread-safe surface access using os_unfair_lock
    private let surfaceLock = OSAllocatedUnfairLock<IOSurface?>(initialState: nil)
    // Thread-safe window reference for updating from stream callback
    private let windowLock = OSAllocatedUnfairLock<CaptureWindow?>(initialState: nil)

    // No artificial cap - use exact region size for 1:1 quality
    // Very large regions (4K+) may impact performance

    override init() {
        super.init()
        // Listen for window close notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowClosed),
            name: .captureWindowClosed,
            object: nil
        )
    }

    @objc private func handleWindowClosed() {
        Task { @MainActor in
            await self.stopCapture()
        }
    }

    func startCapture(region: CGRect, on screen: SCDisplay) async throws {
        Log.debug("CaptureManager: startCapture called for region \(region)")

        // Calculate capture size (cap at 2560x1440)
        let (captureWidth, captureHeight) = calculateCaptureSize(
            sourceWidth: Int(region.width),
            sourceHeight: Int(region.height)
        )
        Log.debug("CaptureManager: capture size \(captureWidth)x\(captureHeight)")

        // Create IOSurface for rendering
        let surfaceProps: [IOSurfacePropertyKey: Any] = [
            .width: captureWidth,
            .height: captureHeight,
            .bytesPerElement: 4,
            .bytesPerRow: captureWidth * 4,
            .pixelFormat: kCVPixelFormatType_32BGRA
        ]

        guard let newSurface = IOSurface(properties: surfaceProps) else {
            Log.debug("CaptureManager: failed to create IOSurface")
            throw CaptureError.surfaceCreationFailed
        }
        surface = newSurface
        surfaceLock.withLock { $0 = newSurface }
        Log.debug("CaptureManager: created IOSurface")

        // Create capture window
        Log.debug("CaptureManager: creating capture window...")
        let window = CaptureWindow(width: captureWidth, height: captureHeight)
        window.orderFront(nil)
        captureWindow = window
        windowLock.withLock { $0 = window }
        Log.debug("CaptureManager: capture window created")

        // Find matching NSScreen for border window
        let nsScreen = screen.matchingNSScreen()
        currentNSScreen = nsScreen
        Log.debug("CaptureManager: matched NSScreen: \(String(describing: nsScreen))")

        // Start the stream
        Log.debug("CaptureManager: starting stream...")
        try await setupAndStartStream(
            region: region,
            screen: screen,
            width: captureWidth,
            height: captureHeight
        )
        Log.debug("CaptureManager: stream started")

        // Show border window around captured region
        if let nsScreen = nsScreen {
            showBorderWindow(frame: region, on: nsScreen)
            Log.debug("CaptureManager: border window shown")
        }

        Log.debug("CaptureManager: startCapture completed successfully")
    }

    func stopCapture() async {
        Log.debug("CaptureManager: stopCapture called")
        if let stream = stream {
            try? await stream.stopCapture()
            Log.debug("CaptureManager: stream stopped")
        }
        stream = nil
        surfaceLock.withLock { $0 = nil }
        windowLock.withLock { $0 = nil }
        surface = nil

        captureWindow?.orderOut(nil)
        captureWindow = nil
        Log.debug("CaptureManager: capture window closed")

        borderWindow?.orderOut(nil)
        borderWindow = nil
        currentRegion = .zero
        currentScreen = nil
        currentNSScreen = nil
        isCapturing = false
        Log.debug("CaptureManager: stopCapture complete")
    }

    func showCaptureWindow() {
        captureWindow?.orderFront(nil)
    }

    func hideCaptureWindow() {
        captureWindow?.orderOut(nil)
    }

    var isCaptureWindowVisible: Bool {
        captureWindow?.isVisible ?? false
    }

    // MARK: - Private Helpers

    private func setupAndStartStream(
        region: CGRect,
        screen: SCDisplay,
        width: Int,
        height: Int
    ) async throws {
        let config = SCStreamConfiguration()
        config.sourceRect = region
        config.width = width
        config.height = height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        config.showsCursor = true

        let filter = SCContentFilter(display: screen, excludingWindows: [])

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "sightline.capture", qos: .userInteractive))
        try await newStream.startCapture()

        self.stream = newStream
        self.currentRegion = region
        self.currentScreen = screen
        self.isCapturing = true
    }

    private func showBorderWindow(frame: CGRect, on screen: NSScreen) {
        // Convert from ScreenCaptureKit coordinates (top-left origin) back to AppKit (bottom-left)
        let appKitFrame = frame.flippedForScreenCapture(screenHeight: screen.frame.height)
        borderWindow = BorderWindow(frame: appKitFrame, on: screen)
        borderWindow?.orderFront(nil)
    }

    private func calculateCaptureSize(sourceWidth: Int, sourceHeight: Int) -> (Int, Int) {
        // Use exact size for 1:1 pixel quality
        // Ensure even dimensions (some encoders require this)
        return (sourceWidth & ~1, sourceHeight & ~1)
    }

    private nonisolated func renderToSurface(pixelBuffer: CVPixelBuffer, surface: IOSurface) {
        let surfaceWidth = IOSurfaceGetWidth(surface)
        let surfaceHeight = IOSurfaceGetHeight(surface)
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Lock surfaces
        IOSurfaceLock(surface, [], nil)
        defer { IOSurfaceUnlock(surface, [], nil) }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let srcBase = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let dstBase = IOSurfaceGetBaseAddress(surface)

        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let dstBytesPerRow = IOSurfaceGetBytesPerRow(surface)

        let copyWidth = min(bufferWidth, surfaceWidth)
        let copyHeight = min(bufferHeight, surfaceHeight)
        let copyBytesPerRow = copyWidth * 4

        for row in 0..<copyHeight {
            let srcRow = srcBase.advanced(by: row * srcBytesPerRow)
            let dstRow = dstBase.advanced(by: row * dstBytesPerRow)
            memcpy(dstRow, srcRow, copyBytesPerRow)
        }
    }
}

// MARK: - SCStreamDelegate

extension CaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Log.debug("Stream stopped with error: \(error)")
        Task { @MainActor in
            await self.stopCapture()
        }
    }
}

// MARK: - SCStreamOutput

extension CaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Thread-safe surface access
        guard let surface = surfaceLock.withLock({ $0 }) else { return }

        renderToSurface(pixelBuffer: pixelBuffer, surface: surface)

        // Update the window with the new surface content (dispatch to main)
        if let window = windowLock.withLock({ $0 }) {
            DispatchQueue.main.async {
                window.updateSurface(surface)
            }
        }
    }
}

// MARK: - Errors

enum CaptureError: LocalizedError {
    case surfaceCreationFailed
    case streamCreationFailed

    var errorDescription: String? {
        switch self {
        case .surfaceCreationFailed:
            return "Failed to create rendering surface"
        case .streamCreationFailed:
            return "Failed to create screen capture stream"
        }
    }
}
