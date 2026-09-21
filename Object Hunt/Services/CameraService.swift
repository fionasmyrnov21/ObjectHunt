import AVFoundation
import Combine
import CoreImage
import UIKit

enum CameraAccess: Equatable {
    case unknown
    case allowed
    case denied
    case missing
}

final class CameraService: NSObject, ObservableObject {
    @Published private(set) var access: CameraAccess = .unknown
    @Published private(set) var isRunning = false
    @Published var lastError: String?

    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()

    var onFrame: ((CIImage) -> Void)?

    private let sessionQueue = DispatchQueue(label: "objecthunt.camera.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var configured = false
    private var lastProcessTime: CFTimeInterval = 0
    private let minimumFrameGap: CFTimeInterval = 0.125

    override init() {
        super.init()
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        refreshAccess()
    }

    func refreshAccess() {
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            access = .missing
            lastError = String(localized: "Camera is not available on this device.")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            access = .allowed
        case .denied, .restricted:
            access = .denied
        case .notDetermined:
            access = .unknown
        @unknown default:
            access = .unknown
        }
    }

    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.access = granted ? .allowed : .denied
            }
        }
    }

    func start() {
        refreshAccess()
        guard access == .allowed else { return }
        sessionQueue.async { [weak self] in
            self?.configureIfNeeded()
            guard let self, self.configured, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func openSystemSettings() {
        guard let destination = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(destination)
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.access = .missing
                self?.lastError = String(localized: "Camera is not available on this device.")
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                session.commitConfiguration()
                DispatchQueue.main.async { [weak self] in
                    self?.lastError = String(localized: "This camera setup is not supported.")
                }
                return
            }

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if let preview = previewLayer.connection, preview.isVideoOrientationSupported {
                preview.videoOrientation = .portrait
            }

            configured = true
            session.commitConfiguration()
        } catch {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.lastError = String(localized: "The camera could not start.")
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastProcessTime >= minimumFrameGap else { return }
        lastProcessTime = now
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: buffer)
        onFrame?(image)
    }
}
