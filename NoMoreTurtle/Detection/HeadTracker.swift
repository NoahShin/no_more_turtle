import CoreGraphics
import CoreMedia
import Vision

struct HeadObservation: Sendable {
    /// Center of the face bounding box, normalized to the image (origin bottom-left).
    let center: CGPoint
    /// Face bounding box in normalized image coordinates.
    let boundingBox: CGRect
    let confidence: Float
}

struct HeadTracker: Sendable {

    static let minimumConfidence: Float = 0.5

    func detect(in buffer: CMSampleBuffer) -> HeadObservation? {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3

        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil else { return nil }

        guard let face = (request.results?.max(by: { $0.confidence < $1.confidence })) else {
            return nil
        }
        guard face.confidence >= Self.minimumConfidence else { return nil }

        return HeadObservation(
            center: CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY),
            boundingBox: face.boundingBox,
            confidence: face.confidence
        )
    }
}
