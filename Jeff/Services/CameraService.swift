import Foundation
import AVFoundation
import CoreImage
import AppKit

public enum CameraError: Error {
    case notAuthorized
    case noDevice
    case configurationFailed
    case captureFailed
}

/// Owns the AVCaptureSession and exposes a single API: grab a still frame
/// "right now". The frame is delivered as a `CGImage` (used by VisionService
/// and the camera preview view).
public final class CameraService: NSObject {
    public private(set) var session = AVCaptureSession()
    public var preferredDeviceID: String?

    private let queue = DispatchQueue(label: "jeff.camera")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var latestFrame: CGImage?
    private let frameLock = NSLock()

    public override init() {
        super.init()
    }

    public func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    public func availableDevices() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .deskViewCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices
    }

    public func start() throws {
        if session.isRunning { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        // Tear down existing inputs/outputs so reconfiguration is idempotent.
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }

        let device = pickDevice()
        guard let device else {
            session.commitConfiguration()
            throw CameraError.noDevice
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }
        session.addOutput(output)
        videoOutput = output

        session.commitConfiguration()
        session.startRunning()
    }

    public func stop() {
        if session.isRunning { session.stopRunning() }
    }

    private func pickDevice() -> AVCaptureDevice? {
        if let id = preferredDeviceID,
           let device = availableDevices().first(where: { $0.uniqueID == id }) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }

    /// Snapshot the latest decoded frame. Returns nil if no frame has been
    /// produced yet — caller should treat that as a soft failure (Jeff just
    /// answers without visual context).
    public func captureStillFrame() -> CGImage? {
        frameLock.lock()
        defer { frameLock.unlock() }
        return latestFrame
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        frameLock.lock()
        latestFrame = cgImage
        frameLock.unlock()
    }
}
