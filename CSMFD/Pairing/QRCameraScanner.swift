import AVFoundation
import CoreImage

/// Back-camera QR reader without UIKit. AVFoundation decodes the codes in hardware;
/// frames become `CGImage`s for a plain SwiftUI `Image` viewfinder.
nonisolated final class QRCameraScanner: NSObject, @unchecked Sendable {
    nonisolated enum Failure: Error, Equatable {
        case accessDenied
        case cameraUnavailable
        case configurationFailed
    }

    /// `CGImage` is immutable, so handing it to the main actor is safe.
    nonisolated struct Frame: @unchecked Sendable {
        let image: CGImage
    }

    /// Only the newest frame matters; older ones are dropped if the UI falls behind.
    let frames: AsyncStream<Frame>
    /// Every decoded string, never dropped.
    let codes: AsyncStream<String>

    private let frameContinuation: AsyncStream<Frame>.Continuation
    private let codeContinuation: AsyncStream<String>.Continuation

    // Everything below is only touched on `queue`, which is what makes `@unchecked Sendable` hold.
    private let queue = DispatchQueue(label: "com.csmfd.qr-scanner")
    private let session = AVCaptureSession()
    private let context = CIContext()
    private var videoConnection: AVCaptureConnection?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    override init() {
        (frames, frameContinuation) = AsyncStream.makeStream(of: Frame.self, bufferingPolicy: .bufferingNewest(1))
        (codes, codeContinuation) = AsyncStream.makeStream(of: String.self)
        super.init()
    }

    func start() async throws(Failure) {
        guard await Self.hasAccess() else { throw .accessDenied }
        // The device is looked up and kept on `queue`; AVCaptureDevice is not Sendable.
        let failure = await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.configureAndRun()) }
        }
        if let failure { throw failure }
    }

    func stop() {
        queue.async {
            self.rotationObservation = nil
            self.rotationCoordinator = nil
            if self.session.isRunning { self.session.stopRunning() }
            self.frameContinuation.finish()
            self.codeContinuation.finish()
        }
    }

    private static func hasAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    /// Runs on `queue`: session configuration and `startRunning` block. Returns nil on success.
    private func configureAndRun() -> Failure? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return .cameraUnavailable
        }
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            session.commitConfiguration()
            return .configurationFailed
        }
        session.addInput(input)

        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        video.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(video) else {
            session.commitConfiguration()
            return .configurationFailed
        }
        session.addOutput(video)
        videoConnection = video.connection(with: .video)

        let metadata = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadata) else {
            session.commitConfiguration()
            return .configurationFailed
        }
        session.addOutput(metadata)
        // Types can only be set after the output joined the session.
        guard metadata.availableMetadataObjectTypes.contains(.qr) else {
            session.commitConfiguration()
            return .configurationFailed
        }
        metadata.metadataObjectTypes = [.qr]
        metadata.setMetadataObjectsDelegate(self, queue: queue)
        session.commitConfiguration()

        // Keep the frames upright however the iPad is held.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            let scanner = self
            scanner?.queue.async { scanner?.applyRotation(angle) }
        }

        session.startRunning()
        return session.isRunning ? nil : .configurationFailed
    }

    private func applyRotation(_ angle: CGFloat) {
        guard let videoConnection, videoConnection.isVideoRotationAngleSupported(angle) else { return }
        videoConnection.videoRotationAngle = angle
    }
}

nonisolated extension QRCameraScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return }
        frameContinuation.yield(Frame(image: cgImage))
    }
}

nonisolated extension QRCameraScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for case let code as AVMetadataMachineReadableCodeObject in metadataObjects {
            if let value = code.stringValue {
                codeContinuation.yield(value)
            }
        }
    }
}
