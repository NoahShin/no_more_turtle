import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let monitor = PostureMonitor()
    private lazy var settingsWindowController = SettingsWindowController(settings: AppSettings.shared)
    private var toggleMenuItem: NSMenuItem!
    private var calibrateGoodItem: NSMenuItem!
    private var calibrateTurtleItem: NSMenuItem!
    private var clearCalibrationItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        monitor.onStateChange = { [weak self] in self?.refreshMenu() }
        refreshMenu()
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐢"

        let menu = NSMenu()
        menu.autoenablesItems = false

        toggleMenuItem = NSMenuItem(
            title: "Start monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: "s"
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(.separator())

        calibrateGoodItem = NSMenuItem(
            title: "Calibrate good posture",
            action: #selector(calibrateGood),
            keyEquivalent: "g"
        )
        calibrateGoodItem.target = self
        menu.addItem(calibrateGoodItem)

        calibrateTurtleItem = NSMenuItem(
            title: "Calibrate turtle posture",
            action: #selector(calibrateTurtle),
            keyEquivalent: "t"
        )
        calibrateTurtleItem.target = self
        menu.addItem(calibrateTurtleItem)

        clearCalibrationItem = NSMenuItem(
            title: "Clear calibration",
            action: #selector(clearCalibration),
            keyEquivalent: ""
        )
        clearCalibrationItem.target = self
        menu.addItem(clearCalibrationItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

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

        let canCapture = monitor.isMonitoring
        calibrateGoodItem.isEnabled = canCapture
        calibrateTurtleItem.isEnabled = canCapture

        calibrateGoodItem.title = monitor.goodPosture == nil
            ? "Calibrate good posture (sit upright!)"
            : "Re-calibrate good posture ✓"
        calibrateTurtleItem.title = monitor.turtlePosture == nil
            ? "Calibrate turtle posture (slouch like turtle!)"
            : "Re-calibrate turtle posture ✓"

        clearCalibrationItem.isEnabled = monitor.goodPosture != nil || monitor.turtlePosture != nil
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

    @objc private func calibrateGood() {
        showCalibrationResult(monitor.calibrateGoodPosture(), pose: "good")
    }

    @objc private func calibrateTurtle() {
        showCalibrationResult(monitor.calibrateTurtlePosture(), pose: "turtle")
    }

    @objc private func clearCalibration() {
        monitor.clearCalibration()
    }

    @objc private func openSettings() {
        settingsWindowController.openWindow()
    }

    private func showCalibrationResult(_ result: PostureMonitor.CalibrationResult, pose: String) {
        switch result {
        case .captured:
            return
        case .noFace:
            let alert = NSAlert()
            alert.messageText = "캘리브레이션 실패"
            alert.informativeText = "카메라에서 얼굴이 감지되지 않습니다. 자세 잡고 잠시 기다린 뒤 다시 시도해주세요."
            alert.alertStyle = .informational
            alert.runModal()
        case .tooClose:
            let alert = NSAlert()
            alert.messageText = "캘리브레이션 실패"
            alert.informativeText = "\(pose == "good" ? "좋은" : "거북목") 자세가 반대편 자세와 너무 비슷합니다. 자세 차이를 더 크게 만들고 다시 시도해주세요."
            alert.alertStyle = .informational
            alert.runModal()
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
