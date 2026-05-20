import CoreGraphics
import Vision

struct PostureVerdict {
    let isTurtle: Bool
    let confidence: Float
    let neckRatio: CGFloat
}

enum PostureAnalyzer {

    static let minimumJointConfidence: Float = 0.3

    /// Below this ratio the head is considered jutted forward / dropped (turtle-neck).
    /// Ratio = (avg ear Y − avg shoulder Y) / shoulder width.
    /// Tuned empirically; expose as a setting later.
    static let turtleRatioThreshold: CGFloat = 0.35

    static func analyze(_ observation: VNHumanBodyPoseObservation) -> PostureVerdict? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        guard
            let leftEar = points[.leftEar],
            let rightEar = points[.rightEar],
            let leftShoulder = points[.leftShoulder],
            let rightShoulder = points[.rightShoulder],
            leftEar.confidence >= minimumJointConfidence,
            rightEar.confidence >= minimumJointConfidence,
            leftShoulder.confidence >= minimumJointConfidence,
            rightShoulder.confidence >= minimumJointConfidence
        else { return nil }

        let earY = (leftEar.location.y + rightEar.location.y) / 2
        let shoulderY = (leftShoulder.location.y + rightShoulder.location.y) / 2
        let shoulderWidth = abs(leftShoulder.location.x - rightShoulder.location.x)

        guard shoulderWidth > 0.01 else { return nil }

        let neckRatio = (earY - shoulderY) / shoulderWidth
        let lowestConfidence = min(
            leftEar.confidence, rightEar.confidence,
            leftShoulder.confidence, rightShoulder.confidence
        )

        return PostureVerdict(
            isTurtle: neckRatio < turtleRatioThreshold,
            confidence: lowestConfidence,
            neckRatio: neckRatio
        )
    }
}
