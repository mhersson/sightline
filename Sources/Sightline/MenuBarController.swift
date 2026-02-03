import AppKit

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let captureManager = CaptureManager()
    private var isSelectingRegion = false

    init() {
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "Sightline")
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if captureManager.isCapturing {
            menu.addItem(withTitle: "Capturing...", action: nil, keyEquivalent: "").isEnabled = false
            menu.addItem(NSMenuItem.separator())

            let selectItem = NSMenuItem(title: "Select New Region", action: #selector(selectRegion), keyEquivalent: "")
            selectItem.target = self
            selectItem.isEnabled = !isSelectingRegion
            menu.addItem(selectItem)

            menu.addItem(NSMenuItem.separator())

            // Show/Hide capture window toggle
            let windowTitle = captureManager.isCaptureWindowVisible ? "Hide Capture Window" : "Show Capture Window"
            menu.addItem(withTitle: windowTitle, action: #selector(toggleCaptureWindow), keyEquivalent: "").target = self

            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Stop Sharing", action: #selector(stopSharing), keyEquivalent: "").target = self
        } else {
            let selectItem = NSMenuItem(title: "Select Region", action: #selector(selectRegion), keyEquivalent: "")
            selectItem.target = self
            selectItem.isEnabled = !isSelectingRegion
            menu.addItem(selectItem)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "").target = self

        statusItem?.menu = menu
    }

    @objc private func selectRegion() {
        guard !isSelectingRegion else {
            Log.debug("Already selecting region, ignoring")
            return
        }

        isSelectingRegion = true
        Log.debug("selectRegion: starting")

        Task {
            if captureManager.isCapturing {
                Log.debug("selectRegion: stopping existing capture")
                await captureManager.stopCapture()
                updateStatusIcon(capturing: false)
            }

            Log.debug("selectRegion: creating overlay")
            let overlay = SelectionOverlay()

            Log.debug("selectRegion: calling waitForSelection")
            let selection = await overlay.waitForSelection()

            // Selection UI is done - allow new selections
            isSelectingRegion = false
            rebuildMenu()

            Log.debug("selectRegion: waitForSelection returned: \(String(describing: selection))")

            if let selection = selection {
                Log.debug("selectRegion: starting capture")
                do {
                    try await captureManager.startCapture(region: selection.rect, on: selection.screen)
                    updateStatusIcon(capturing: true)
                    rebuildMenu()
                    Log.debug("selectRegion: capture started")
                } catch {
                    Log.debug("selectRegion: capture failed: \(error)")
                    showError("Failed to start capture: \(error.localizedDescription)")
                    rebuildMenu()
                }
            } else {
                Log.debug("selectRegion: no selection made")
            }
            Log.debug("selectRegion: task completed")
        }
    }

    @objc private func toggleCaptureWindow() {
        if captureManager.isCaptureWindowVisible {
            captureManager.hideCaptureWindow()
        } else {
            captureManager.showCaptureWindow()
        }
        rebuildMenu()
    }

    @objc private func stopSharing() {
        Task {
            await captureManager.stopCapture()
            rebuildMenu()
            updateStatusIcon(capturing: false)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateStatusIcon(capturing: Bool) {
        if let button = statusItem?.button {
            let symbolName = capturing ? "rectangle.dashed.badge.record" : "rectangle.dashed"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Sightline")
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}
