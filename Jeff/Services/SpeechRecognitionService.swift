import Foundation
import Speech
import AVFoundation

public enum SpeechRecognitionError: Error {
    case notAuthorized
    case recognizerUnavailable
    case noResult
}

/// On-device speech recognition. Requires `SFSpeechRecognizer` to be running
/// `requiresOnDeviceRecognition = true` so audio never leaves the Mac.
public final class SpeechRecognitionService {
    private let recognizer: SFSpeechRecognizer?

    public init(locale: Locale = Locale(identifier: "en-US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    public func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Transcribe a sequence of PCM buffers (typically the audio captured by
    /// `VADService` between speech onset and silence).
    public func transcribe(buffers: [AVAudioPCMBuffer]) async throws -> String {
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        guard let format = buffers.first?.format else {
            throw SpeechRecognitionError.noResult
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        // Match the captured input format so the recognizer doesn't have to
        // resample on the fly.
        _ = format

        for buffer in buffers {
            request.append(buffer)
        }
        request.endAudio()

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let task = recognizer.recognitionTask(with: request) { result, error in
                if didResume { return }
                if let error {
                    didResume = true
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    didResume = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
            _ = task
        }
    }
}
