import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {

    convenience init(settings: AppSettings) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings))

        let window = NSWindow(contentViewController: hosting)
        window.title = "No More Turtle 환경설정"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        self.init(window: window)
    }

    func openWindow() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
