import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let captureManager = CaptureManager()
    private var isSelectingRegion = false

    override init() {
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        captureManager.onStateChange = { [weak self] in self?.updateStatusIcon() }
        updateStatusIcon()
    }

    /// Rebuilt each time it opens, so it reflects capture changes made elsewhere
    /// (window close button, display unplugged, system Stop Sharing).
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if captureManager.isCapturing {
            menu.addItem(withTitle: "Capturing…", action: nil, keyEquivalent: "")
            menu.addItem(.separator())
            addItem("Select New Region", #selector(selectRegion), to: menu)
            menu.addItem(.separator())
            let windowTitle = captureManager.isCaptureWindowVisible ? "Hide Capture Window" : "Show Capture Window"
            addItem(windowTitle, #selector(toggleCaptureWindow), to: menu)
            menu.addItem(.separator())
            addItem("Stop Sharing", #selector(stopSharing), to: menu)
        } else {
            addItem("Select Region", #selector(selectRegion), to: menu)
        }

        menu.addItem(.separator())
        addItem("Quit", #selector(quit), to: menu)
    }

    private func addItem(_ title: String, _ action: Selector, to menu: NSMenu) {
        menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self
    }

    @objc private func selectRegion() {
        guard !isSelectingRegion else { return }

        // Check up front so the user isn't asked to draw a region we can't capture.
        // CGRequestScreenCaptureAccess shows the system prompt the first time only.
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            showError("""
                Sightline needs Screen Recording permission.

                Enable it in System Settings → Privacy & Security → Screen & System Audio Recording, \
                then relaunch Sightline. When running from a terminal, enable the terminal app instead.
                """)
            return
        }

        isSelectingRegion = true
        Task {
            defer { isSelectingRegion = false }

            await captureManager.stopCapture()
            guard let selection = await SelectionOverlay().run() else { return }

            do {
                try await captureManager.startCapture(selection)
            } catch {
                Log.debug("MenuBarController: capture failed: \(error)")
                showError("Failed to start capture: \(error.localizedDescription)")
            }
        }
    }

    @objc private func toggleCaptureWindow() {
        if captureManager.isCaptureWindowVisible {
            captureManager.hideCaptureWindow()
        } else {
            captureManager.showCaptureWindow()
        }
    }

    @objc private func stopSharing() {
        Task { await captureManager.stopCapture() }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateStatusIcon() {
        let symbol = captureManager.isCapturing ? "rectangle.dashed.badge.record" : "rectangle.dashed"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Sightline")
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Sightline"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
