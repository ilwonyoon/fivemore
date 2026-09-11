@preconcurrency import AVFoundation
import UIKit

enum CameraServiceError: LocalizedError {
    case permissionDenied
    case unavailable
    case configurationFailed
    case captureFailed
    case invalidPhotoData

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Camera access is off. Allow camera access in Settings to take a 5 More photo."
        case .unavailable:
            "A camera is not available on this device."
        case .configurationFailed:
            "The camera could not be prepared. Please try again."
        case .captureFailed:
            "The photo could not be captured. Please try again."
        case .invalidPhotoData:
            "The camera returned an unreadable photo. Please try again."
        }
    }
}

@MainActor
final class CameraService: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case running
        case denied
        case unavailable
        case failed
    }

    @Published private(set) var state: State = .idle

    /// Five only after a confident open palm has settled. Nil for partial,
    /// folded or uncertain hands.
    @Published private(set) var stableFingerCount: Int?

    /// Progress toward a stable reading, for the on-screen hold indicator.
    @Published private(set) var detectionProgress: Double = 0

    /// The latest open-palm reading before stabilisation. It exists only to
    /// drive the on-screen "hold steady" guide; manual capture is always five.
    @Published private(set) var latestFingerCount: Int?

#if targetEnvironment(simulator)
    let session: AVCaptureSession? = nil
#else
    let session = AVCaptureSession()
#endif

    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
#if !targetEnvironment(simulator)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.fivemore.app.handpose")
    nonisolated private let detector = HandPoseDetector()
    private var stabilizer = HandPoseStabilizer()
    private var frameDelegate: VideoFrameDelegate?
#endif
#if !targetEnvironment(simulator)
    private var photoDelegate: PhotoCaptureDelegate?
#endif

    func requestAccessAndStart() async -> Bool {
#if targetEnvironment(simulator)
        state = .running
        return true
#else
        state = .requestingPermission

        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        let isAuthorized: Bool

        switch authorization {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        guard isAuthorized else {
            state = .denied
            return false
        }

        do {
            try configureIfNeeded()
            if !session.isRunning {
                session.startRunning()
            }
            state = .running
            return true
        } catch CameraServiceError.unavailable {
            state = .unavailable
            return false
        } catch {
            state = .failed
            return false
        }
#endif
    }

#if targetEnvironment(simulator)
    /// Simulator-only hook so the hand-detection UI can be exercised and
    /// screenshotted without a camera. Never called on device.
    func simulateFingerCount(_ count: Int?, progress: Double = 1) {
        stableFingerCount = count
        latestFingerCount = count
        detectionProgress = progress
    }
#endif

    func stop() {
#if !targetEnvironment(simulator)
        if session.isRunning {
            session.stopRunning()
        }
        stabilizer.reset()
#endif
        stableFingerCount = nil
        latestFingerCount = nil
        detectionProgress = 0

        if state == .running {
            state = .idle
        }
    }

#if !targetEnvironment(simulator)
    /// Called on the video queue for every frame; hands the reading back to the
    /// main actor where the published state lives.
    nonisolated private func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        let count = detector.fingerCount(in: pixelBuffer, orientation: .right)

        Task { @MainActor [weak self] in
            guard let self, self.state == .running else { return }

            if self.latestFingerCount != count {
                self.latestFingerCount = count
            }

            let stable = self.stabilizer.accept(count)
            if self.stableFingerCount != stable {
                self.stableFingerCount = stable
            }

            let progress = self.stabilizer.progress
            if abs(self.detectionProgress - progress) > 0.001 {
                self.detectionProgress = progress
            }
        }
    }
#endif

    func capturePhoto() async throws -> Data {
#if targetEnvironment(simulator)
        guard state == .running else { throw CameraServiceError.unavailable }
        return makeSimulatorPhoto()
#else
        guard state == .running, isConfigured else {
            throw CameraServiceError.configurationFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate { [weak self] result in
                Task { @MainActor in
                    self?.photoDelegate = nil
                    continuation.resume(with: result)
                }
            }
            photoDelegate = delegate

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality

            if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }

            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
#endif
    }

#if !targetEnvironment(simulator)
    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraServiceError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw CameraServiceError.configurationFailed
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        if session.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            let delegate = VideoFrameDelegate { [weak self] buffer in
                self?.handleFrame(buffer)
            }
            frameDelegate = delegate
            videoOutput.setSampleBufferDelegate(delegate, queue: videoQueue)
            session.addOutput(videoOutput)
        }

        isConfigured = true
    }
#endif

#if targetEnvironment(simulator)
    private func makeSimulatorPhoto() -> Data {
        let size = CGSize(width: 1_200, height: 1_600)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.jpegData(withCompressionQuality: 0.92) { context in
            UIColor(red: 0.97, green: 0.93, blue: 0.83, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let configuration = UIImage.SymbolConfiguration(pointSize: 340, weight: .regular)
            let hand = UIImage(systemName: "hand.raised.fill", withConfiguration: configuration)?
                .withTintColor(UIColor(red: 0.93, green: 0.57, blue: 0.42, alpha: 1), renderingMode: .alwaysOriginal)
            hand?.draw(in: CGRect(x: 385, y: 390, width: 430, height: 520))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .bold),
                .foregroundColor: UIColor(red: 0.12, green: 0.13, blue: 0.13, alpha: 1),
                .paragraphStyle: paragraph
            ]
            NSString(string: "A 5 More preview moment").draw(
                in: CGRect(x: 90, y: 1_020, width: 1_020, height: 180),
                withAttributes: attributes
            )
        }
    }
#endif
}

#if !targetEnvironment(simulator)
/// Bridges the capture queue's sample buffers to a plain closure.
private final class VideoFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onFrame: @Sendable (CVPixelBuffer) -> Void

    init(onFrame: @escaping @Sendable (CVPixelBuffer) -> Void) {
        self.onFrame = onFrame
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame(buffer)
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraServiceError.invalidPhotoData))
            return
        }

        completion(.success(data))
    }
}
#endif
