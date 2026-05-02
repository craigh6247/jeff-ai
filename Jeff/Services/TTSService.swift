import Foundation
import AVFoundation

public protocol TTSServiceDelegate: AnyObject {
    func ttsDidStart(_ service: TTSService)
    func ttsDidFinish(_ service: TTSService)
    func ttsDidCancel(_ service: TTSService)
}

/// Thin wrapper over `AVSpeechSynthesizer`. Exposes the voice list, rate,
/// volume controls, and a single `interrupt()` for the configurable hotkey.
public final class TTSService: NSObject {
    public weak var delegate: TTSServiceDelegate?

    private let synthesizer = AVSpeechSynthesizer()

    public var voiceIdentifier: String?
    public var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    public var volume: Float = 1.0

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }

    public func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: trimmed)
        if let voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        }
        utterance.rate = rate
        utterance.volume = volume
        synthesizer.speak(utterance)
    }

    public func interrupt() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    public var isSpeaking: Bool { synthesizer.isSpeaking }
}

extension TTSService: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        delegate?.ttsDidStart(self)
    }
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        delegate?.ttsDidFinish(self)
    }
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        delegate?.ttsDidCancel(self)
    }
}
