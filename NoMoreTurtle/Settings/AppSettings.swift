import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private enum Keys {
        static let scoreThreshold = "settings.scoreThreshold"
        static let overlaySize = "settings.overlaySize"
        static let overlayOpacity = "settings.overlayOpacity"
        static let autoStartMonitoring = "settings.autoStartMonitoring"
    }

    static let defaultScoreThreshold: Double = 0.65
    static let defaultOverlaySize: Double = 600
    static let defaultOverlayOpacity: Double = 0.55
    static let defaultAutoStartMonitoring: Bool = false

    @Published var scoreThreshold: Double {
        didSet { UserDefaults.standard.set(scoreThreshold, forKey: Keys.scoreThreshold) }
    }
    @Published var overlaySize: Double {
        didSet { UserDefaults.standard.set(overlaySize, forKey: Keys.overlaySize) }
    }
    @Published var overlayOpacity: Double {
        didSet { UserDefaults.standard.set(overlayOpacity, forKey: Keys.overlayOpacity) }
    }
    @Published var autoStartMonitoring: Bool {
        didSet { UserDefaults.standard.set(autoStartMonitoring, forKey: Keys.autoStartMonitoring) }
    }

    private init() {
        let defaults = UserDefaults.standard
        scoreThreshold = (defaults.object(forKey: Keys.scoreThreshold) as? Double) ?? Self.defaultScoreThreshold
        overlaySize = (defaults.object(forKey: Keys.overlaySize) as? Double) ?? Self.defaultOverlaySize
        overlayOpacity = (defaults.object(forKey: Keys.overlayOpacity) as? Double) ?? Self.defaultOverlayOpacity
        autoStartMonitoring = (defaults.object(forKey: Keys.autoStartMonitoring) as? Bool) ?? Self.defaultAutoStartMonitoring
    }

    func resetToDefaults() {
        scoreThreshold = Self.defaultScoreThreshold
        overlaySize = Self.defaultOverlaySize
        overlayOpacity = Self.defaultOverlayOpacity
        autoStartMonitoring = Self.defaultAutoStartMonitoring
    }
}
