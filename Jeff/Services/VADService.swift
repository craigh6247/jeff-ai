import Foundation
import AVFoundation

public protocol VADDelegate: AnyObject {
    func vadDidDetectSpeechStart(_ vad: VADService)
    func vadDidDetectSpeechEnd(_ vad: VADService, capturedAudio: [AVAudioPCMBuffer])
}

/// Energy-based voice activity detector with hysteresis.
///
/// Real-world deployment should swap the energy heuristic for Silero or
/// WebRTC VAD. The interface here is intentionally simple so that drop-in
/// replacement is trivial — only `evaluate(buffer:)` needs new internals.
public final class VADService: AudioCaptureDelegate {
    public weak var delegate: VADDelegate?

    private let queue = DispatchQueue(label: "jeff.vad")

    // Tunables
    public var energyThreshold: Float = VADSensitivity.medium.energyThreshold
    public var silenceTimeout: TimeInterval = 1.5
    public var minSpeechDuration: TimeInterval = 0.25
    public var preRollSeconds: TimeInterval = 0.4
    public var enabled: Bool = true

    // State
    private var inSpeech = false
    private var speechStartTime: Date?
    private var lastVoicedTime: Date?
    private var speechBuffers: [AVAudioPCMBuffer] = []
    private var preRollBuffers: [AVAudioPCMBuffer] = []
    private var preRollSampleCount: AVAudioFrameCount = 0

    public init() {}

    // MARK: AudioCaptureDelegate

    public func audioCapture(_ service: AudioCaptureService, didCapture buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            self?.evaluate(buffer: buffer)
        }
    }

    // MARK: Detection

    private func evaluate(buffer: AVAudioPCMBuffer) {
        guard enabled else { return }
        let energy = rms(buffer)
        let now = Date()

        if energy >= energyThreshold {
            if !inSpeech {
                inSpeech = true
                speechStartTime = now
                speechBuffers.removeAll(keepingCapacity: true)
                speechBuffers.append(contentsOf: preRollBuffers)
                preRollBuffers.removeAll(keepingCapacity: true)
                preRollSampleCount = 0
                DispatchQueue.main.async {
                    self.delegate?.vadDidDetectSpeechStart(self)
                }
            }
            speechBuffers.append(buffer)
            lastVoicedTime = now
        } else if inSpeech {
            speechBuffers.append(buffer)
            if let last = lastVoicedTime, now.timeIntervalSince(last) >= silenceTimeout {
                let started = speechStartTime ?? now
                let duration = now.timeIntervalSince(started)
                let captured = speechBuffers
                let qualified = duration >= minSpeechDuration
                resetSpeechState()
                if qualified {
                    DispatchQueue.main.async {
                        self.delegate?.vadDidDetectSpeechEnd(self, capturedAudio: captured)
                    }
                }
            }
        } else {
            preRollBuffers.append(buffer)
            preRollSampleCount += buffer.frameLength
            trimPreRoll(format: buffer.format)
        }
    }

    private func resetSpeechState() {
        inSpeech = false
        speechStartTime = nil
        lastVoicedTime = nil
        speechBuffers.removeAll(keepingCapacity: true)
    }

    private func trimPreRoll(format: AVAudioFormat) {
        let maxSamples = AVAudioFrameCount(preRollSeconds * format.sampleRate)
        while preRollSampleCount > maxSamples, let first = preRollBuffers.first {
            preRollSampleCount = preRollSampleCount > first.frameLength
                ? preRollSampleCount - first.frameLength
                : 0
            preRollBuffers.removeFirst()
        }
    }

    private func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sumSquares: Float = 0
        for ch in 0..<channels {
            let samples = channelData[ch]
            for i in 0..<frames {
                let s = samples[i]
                sumSquares += s * s
            }
        }
        let mean = sumSquares / Float(frames * max(channels, 1))
        return sqrtf(mean)
    }
}
