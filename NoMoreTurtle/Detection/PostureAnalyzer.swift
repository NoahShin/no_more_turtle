import CoreGraphics
import Foundation

struct PostureBaseline: Sendable, Codable {
    let center: CGPoint
    let boundingBox: CGRect
}

struct CalibrationProfile: Sendable, Codable {
    let good: PostureBaseline
    let turtle: PostureBaseline
}

struct PostureVerdict: Sendable {
    let isTurtle: Bool
    /// 0 = at the good baseline, 1 = at the turtle baseline, can exceed in either direction.
    let score: CGFloat
}

enum PostureAnalyzer {

    /// Reject calibrations where good and turtle are too close to distinguish — needed to keep the projection stable.
    static let minimumSeparation: CGFloat = 0.05

    static func separation(good: PostureBaseline, turtle: PostureBaseline) -> CGFloat {
        sqrt(magnitudeSquared(from: good, to: turtle))
    }

    static func analyze(
        observation: HeadObservation,
        profile: CalibrationProfile,
        threshold: CGFloat
    ) -> PostureVerdict {
        let g = profile.good
        let t = profile.turtle

        // 4D feature vector: head center (x, y) + bbox size (w, h), all in normalized image units.
        let dirMagSq = magnitudeSquared(from: g, to: t)
        guard dirMagSq > 1e-6 else {
            return PostureVerdict(isTurtle: false, score: 0)
        }

        let dot =
            (observation.center.x - g.center.x) * (t.center.x - g.center.x) +
            (observation.center.y - g.center.y) * (t.center.y - g.center.y) +
            (observation.boundingBox.width - g.boundingBox.width)
                * (t.boundingBox.width - g.boundingBox.width) +
            (observation.boundingBox.height - g.boundingBox.height)
                * (t.boundingBox.height - g.boundingBox.height)

        let score = dot / dirMagSq
        return PostureVerdict(isTurtle: score > threshold, score: score)
    }

    private static func magnitudeSquared(from a: PostureBaseline, to b: PostureBaseline) -> CGFloat {
        let dx = b.center.x - a.center.x
        let dy = b.center.y - a.center.y
        let dw = b.boundingBox.width - a.boundingBox.width
        let dh = b.boundingBox.height - a.boundingBox.height
        return dx * dx + dy * dy + dw * dw + dh * dh
    }
}
