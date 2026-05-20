import AppKit
import CoreMedia

@MainActor
final class PostureMonitor {

    private let camera = CameraManager()
    nonisolated private let detector = PoseDetector()
    private let overlay = TurtleOverlayWindow()

    private(set) var isMonitoring = false
    var onStateChange: (() -> Void)?

    func start() async throws {
        guard !isMonitoring else { return }

        let granted = await camera.requestPermission()
        guard granted else { throw MonitorError.cameraPermissionDenied }

        camera.onFrame = { [weak self] buffer in
            guard let self else { return }
            let verdict = self.evaluate(buffer)
            Task { @MainActor in self.apply(verdict) }
        }

        try camera.start()
        isMonitoring = true
        onStateChange?()
    }

    func stop() {
        guard isMonitoring else { return }
        camera.stop()
        overlay.hide()
        isMonitoring = false
        onStateChange?()
    }

    nonisolated private func evaluate(_ buffer: CMSampleBuffer) -> PostureVerdict? {
        guard let observation = try? detector.detect(in: buffer) else { return nil }
        return PostureAnalyzer.analyze(observation)
    }

    private func apply(_ verdict: PostureVerdict?) {
        guard let verdict else { return }
        if verdict.isTurtle {
            overlay.show()
        } else {
            overlay.hide()
        }
    }
}

enum MonitorError: LocalizedError {
    case cameraPermissionDenied

    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "카메라 권한이 필요합니다. 시스템 설정 → 개인정보 보호 및 보안 → 카메라에서 No More Turtle을 허용해주세요."
        }
    }
}
