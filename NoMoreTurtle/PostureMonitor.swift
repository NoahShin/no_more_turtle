import AppKit
import CoreMedia
import OSLog

@MainActor
final class PostureMonitor {

    private enum DefaultsKeys {
        static let goodPosture = "calibration.good"
        static let turtlePosture = "calibration.turtle"
    }

    private let log = Logger(subsystem: "io.github.noahshin.NoMoreTurtle", category: "PostureMonitor")

    private let camera = CameraManager()
    nonisolated private let tracker = HeadTracker()
    private let overlay = TurtleOverlayWindow()

    private(set) var isMonitoring = false
    private(set) var goodPosture: PostureBaseline? {
        didSet { Self.persist(goodPosture, key: DefaultsKeys.goodPosture) }
    }
    private(set) var turtlePosture: PostureBaseline? {
        didSet { Self.persist(turtlePosture, key: DefaultsKeys.turtlePosture) }
    }
    private var lastObservation: HeadObservation?

    var onStateChange: (() -> Void)?

    init() {
        goodPosture = Self.loadBaseline(key: DefaultsKeys.goodPosture)
        turtlePosture = Self.loadBaseline(key: DefaultsKeys.turtlePosture)
        if goodPosture != nil || turtlePosture != nil {
            let status = describeCalibrationStatus()
            print("🎯 loaded saved calibration — \(status)")
            log.notice("loaded saved calibration: \(status, privacy: .public)")
        }
    }

    private static func persist(_ baseline: PostureBaseline?, key: String) {
        if let baseline, let data = try? JSONEncoder().encode(baseline) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func loadBaseline(key: String) -> PostureBaseline? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PostureBaseline.self, from: data)
    }

    /// Consecutive raw turtle/normal frames required to flip the displayed state.
    /// Enter is faster so the user gets quick feedback; exit is slower so brief good-posture moments don't dismiss the overlay.
    private let enterStreakRequired = 8       // ~0.27s at 30fps
    private let exitStreakRequired = 15       // ~0.5s at 30fps

    private var frameCount = 0
    private var rawTurtleStreak = 0
    private var rawNormalStreak = 0
    private var displayedTurtle = false
    private var lastNoFaceLog = Date.distantPast

    enum CalibrationResult {
        case captured
        case noFace
        case tooClose
    }

    var calibrationProfile: CalibrationProfile? {
        guard let good = goodPosture, let turtle = turtlePosture else { return nil }
        return CalibrationProfile(good: good, turtle: turtle)
    }

    func start() async throws {
        guard !isMonitoring else { return }

        let granted = await camera.requestPermission()
        guard granted else { throw MonitorError.cameraPermissionDenied }

        camera.onFrame = { [weak self] buffer in
            guard let self else { return }
            let observation = self.detect(buffer)
            Task { @MainActor in self.apply(observation) }
        }

        try camera.start()
        isMonitoring = true
        onStateChange?()
        log.notice("monitoring started")
        print("🐢 monitoring started")
    }

    func stop() {
        guard isMonitoring else { return }
        camera.stop()
        overlay.hide()
        isMonitoring = false
        frameCount = 0
        rawTurtleStreak = 0
        rawNormalStreak = 0
        displayedTurtle = false
        lastObservation = nil
        onStateChange?()
        log.notice("monitoring stopped")
        print("🐢 monitoring stopped")
    }

    /// Capture current head observation as the user's good (upright) posture baseline.
    @discardableResult
    func calibrateGoodPosture() -> CalibrationResult {
        guard let obs = lastObservation else {
            print("⚠️ calibrate good failed: no face detected")
            return .noFace
        }
        let candidate = PostureBaseline(center: obs.center, boundingBox: obs.boundingBox)
        if let turtle = turtlePosture,
           PostureAnalyzer.separation(good: candidate, turtle: turtle) < PostureAnalyzer.minimumSeparation {
            print("⚠️ calibrate good failed: too close to turtle baseline")
            return .tooClose
        }
        goodPosture = candidate
        resetSmoothing()
        let msg = String(
            format: "🎯 good posture calibrated: center=(%.3f, %.3f) bbox=(%.3f, %.3f)",
            obs.center.x, obs.center.y, obs.boundingBox.width, obs.boundingBox.height
        )
        print(msg)
        log.notice("\(msg, privacy: .public)")
        onStateChange?()
        return .captured
    }

    /// Capture current head observation as the user's turtle (slouched) posture baseline.
    @discardableResult
    func calibrateTurtlePosture() -> CalibrationResult {
        guard let obs = lastObservation else {
            print("⚠️ calibrate turtle failed: no face detected")
            return .noFace
        }
        let candidate = PostureBaseline(center: obs.center, boundingBox: obs.boundingBox)
        if let good = goodPosture,
           PostureAnalyzer.separation(good: good, turtle: candidate) < PostureAnalyzer.minimumSeparation {
            print("⚠️ calibrate turtle failed: too close to good baseline")
            return .tooClose
        }
        turtlePosture = candidate
        resetSmoothing()
        let msg = String(
            format: "🐢 turtle posture calibrated: center=(%.3f, %.3f) bbox=(%.3f, %.3f)",
            obs.center.x, obs.center.y, obs.boundingBox.width, obs.boundingBox.height
        )
        print(msg)
        log.notice("\(msg, privacy: .public)")
        onStateChange?()
        return .captured
    }

    func clearCalibration() {
        goodPosture = nil
        turtlePosture = nil
        overlay.hide()
        resetSmoothing()
        onStateChange?()
        print("🎯 calibration cleared")
    }

    private func resetSmoothing() {
        rawTurtleStreak = 0
        rawNormalStreak = 0
        displayedTurtle = false
    }

    nonisolated private func detect(_ buffer: CMSampleBuffer) -> HeadObservation? {
        tracker.detect(in: buffer)
    }

    private func apply(_ observation: HeadObservation?) {
        frameCount += 1
        lastObservation = observation

        guard let observation else {
            let now = Date()
            if now.timeIntervalSince(lastNoFaceLog) > 2 {
                print("… no face detected (frame \(frameCount))")
                lastNoFaceLog = now
            }
            return
        }

        guard let profile = calibrationProfile else {
            if frameCount % 30 == 0 {
                let status = describeCalibrationStatus()
                let msg = String(
                    format: "frame=%d head=(%.3f, %.3f) conf=%.2f — %@",
                    frameCount, observation.center.x, observation.center.y, observation.confidence, status
                )
                print(msg)
            }
            return
        }

        let verdict = PostureAnalyzer.analyze(
            observation: observation,
            profile: profile,
            threshold: AppSettings.shared.scoreThreshold
        )

        if verdict.isTurtle {
            rawTurtleStreak += 1
            rawNormalStreak = 0
        } else {
            rawNormalStreak += 1
            rawTurtleStreak = 0
        }

        let previouslyDisplayed = displayedTurtle
        if !displayedTurtle, rawTurtleStreak >= enterStreakRequired {
            displayedTurtle = true
        } else if displayedTurtle, rawNormalStreak >= exitStreakRequired {
            displayedTurtle = false
        }

        if frameCount % 30 == 0 {
            let msg = String(
                format: "frame=%d score=%.2f raw=%@ shown=%@ streaks(t/n)=%d/%d",
                frameCount, verdict.score,
                verdict.isTurtle ? "YES" : "no",
                displayedTurtle ? "YES" : "no",
                rawTurtleStreak, rawNormalStreak
            )
            print(msg)
            log.notice("\(msg, privacy: .public)")
        }

        if displayedTurtle != previouslyDisplayed {
            let msg = displayedTurtle
                ? String(format: "🐢 TURTLE shown (score=%.2f, streak=%d)", verdict.score, rawTurtleStreak)
                : String(format: "✓ good posture (score=%.2f, streak=%d)", verdict.score, rawNormalStreak)
            print(msg)
            log.notice("\(msg, privacy: .public)")
        }

        if displayedTurtle {
            overlay.show()
        } else {
            overlay.hide()
        }
    }

    private func describeCalibrationStatus() -> String {
        switch (goodPosture, turtlePosture) {
        case (nil, nil): return "no calibration yet"
        case (.some, nil): return "good captured, need turtle"
        case (nil, .some): return "turtle captured, need good"
        case (.some, .some): return "calibrated"
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
