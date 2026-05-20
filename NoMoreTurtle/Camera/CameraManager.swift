import AVFoundation

final class CameraManager: NSObject {

    enum CameraError: LocalizedError {
        case noDevice
        case cannotAddInput
        case cannotAddOutput

        var errorDescription: String? {
            switch self {
            case .noDevice: return "카메라 디바이스를 찾을 수 없습니다."
            case .cannotAddInput: return "카메라 입력을 추가할 수 없습니다."
            case .cannotAddOutput: return "비디오 출력을 추가할 수 없습니다."
            }
        }
    }

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "io.github.noahshin.NoMoreTurtle.camera", qos: .userInitiated)

    var onFrame: ((CMSampleBuffer) -> Void)?

    override init() {
        super.init()
        videoOutput.setSampleBufferDelegate(self, queue: queue)
    }

    func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func start() throws {
        if session.inputs.isEmpty {
            try configure()
        }
        guard !session.isRunning else { return }
        queue.async { [session] in session.startRunning() }
    }

    func stop() {
        guard session.isRunning else { return }
        queue.async { [session] in session.stopRunning() }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .vga640x480

        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
        guard let device else { throw CameraError.noDevice }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else { throw CameraError.cannotAddOutput }
        session.addOutput(videoOutput)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer)
    }
}
