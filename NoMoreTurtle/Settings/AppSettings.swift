import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private enum Keys {
        static let scoreThreshold = "settings.scoreThreshold"
        static let overlaySize = "settings.overlaySize"
        static let overlayOpacity = "settings.overlayOpacity"
    }

    static let defaultScoreThreshold: Double = 0.65
    static let defaultOverlaySize: Double = 600
    static let defaultOverlayOpacity: Double = 0.55

    @Published var scoreThreshold: Double {
        didSet { UserDefaults.standard.set(scoreThreshold, forKey: Keys.scoreThreshold) }
    }
    @Published var overlaySize: Double {
        didSet { UserDefaults.standard.set(overlaySize, forKey: Keys.overlaySize) }
    }
    @Published var overlayOpacity: Double {
        didSet { UserDefaults.standard.set(overlayOpacity, forKey: Keys.overlayOpacity) }
    }

    private init() {
        let defaults = UserDefaults.standard
        scoreThreshold = (defaults.object(forKey: Keys.scoreThreshold) as? Double) ?? Self.defaultScoreThreshold
        overlaySize = (defaults.object(forKey: Keys.overlaySize) as? Double) ?? Self.defaultOverlaySize
        overlayOpacity = (defaults.object(forKey: Keys.overlayOpacity) as? Double) ?? Self.defaultOverlayOpacity
    }

    func resetToDefaults() {
        scoreThreshold = Self.defaultScoreThreshold
        overlaySize = Self.defaultOverlaySize
        overlayOpacity = Self.defaultOverlayOpacity
    }
}
