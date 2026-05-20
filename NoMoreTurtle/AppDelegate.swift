import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let monitor = PostureMonitor()
    private var toggleMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        monitor.onStateChange = { [weak self] in self?.refreshMenu() }
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐢"

        let menu = NSMenu()
        toggleMenuItem = NSMenuItem(
            title: "Start monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: "s"
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit No More Turtle",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    private func refreshMenu() {
        toggleMenuItem.title = monitor.isMonitoring ? "Stop monitoring" : "Start monitoring"
    }

    @objc private func toggleMonitoring() {
        if monitor.isMonitoring {
            monitor.stop()
        } else {
            Task { [monitor] in
                do {
                    try await monitor.start()
                } catch {
                    await MainActor.run { Self.presentError(error) }
                }
            }
        }
    }

    private static func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "No More Turtle"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
