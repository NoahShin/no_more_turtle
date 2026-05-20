import CoreMedia
import Vision

struct PoseDetector: Sendable {

    func detect(in buffer: CMSampleBuffer) throws -> VNHumanBodyPoseObservation? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .up, options: [:])
        try handler.perform([request])
        return request.results?.first
    }
}
