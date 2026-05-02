import Foundation
import AVFoundation

public protocol AudioCaptureDelegate: AnyObject {
    /// Called on a private serial queue with each microphone PCM buffer.
    func audioCapture(_ service: AudioCaptureService, didCapture buffer: AVAudioPCMBuffer)
}

/// Owns the shared `AVAudioEngine` and taps the input node to deliver PCM
/// buffers continuously while the app is running and not muted.
public final class AudioCaptureService {
    public weak var delegate: AudioCaptureDelegate?

    private let engine = AVAudioEngine()
    private let bus: AVAudioNodeBus = 0
    private let bufferSize: AVAudioFrameCount = 1024
    private var isTapped = false

    public var format: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: bus)
    }

    public init() {}

    public func start() throws {
        guard !engine.isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: bus)

        if !isTapped {
            input.installTap(onBus: bus, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
                guard let self else { return }
                self.delegate?.audioCapture(self, didCapture: buffer)
            }
            isTapped = true
        }

        engine.prepare()
        try engine.start()
    }

    public func stop() {
        guard engine.isRunning else { return }
        engine.stop()
        if isTapped {
            engine.inputNode.removeTap(onBus: bus)
            isTapped = false
        }
    }
}
