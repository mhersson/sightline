import AppKit
@preconcurrency import ScreenCaptureKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await checkScreenCapturePermission()
        }
        menuBarController = MenuBarController()
    }

    private func checkScreenCapturePermission() async {
        do {
            // This triggers the permission prompt if not already granted
            _ = try await SCShareableContent.current
        } catch {
            showPermissionAlert()
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
            Sightline needs screen recording permission to capture your screen region.

            Please enable it in:
            System Settings → Privacy & Security → Screen Recording

            Note: When running from terminal, the permission may appear under your terminal app's name (e.g., Terminal, iTerm, WezTerm). Enable that instead.

            After enabling, restart Sightline.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Continue Anyway")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            NSApp.terminate(nil)
        } else if response == .alertThirdButtonReturn {
            NSApp.terminate(nil)
        }
        // Continue anyway - user can grant permission later
    }
}
