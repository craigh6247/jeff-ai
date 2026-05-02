import Foundation
import AVFoundation
import Combine
import AppKit

/// Owns the full request lifecycle and exposes the published state the SwiftUI
/// views observe. Wires together: audio capture → VAD → speech recognition →
/// camera + vision → context → MLX → TTS → memory.
@MainActor
public final class PipelineCoordinator: ObservableObject {
    @Published public private(set) var state: AppState = .idle
    @Published public private(set) var lastQuestion: String = ""
    @Published public private(set) var lastAnswer: String = ""
    @Published public var isMuted: Bool = false {
        didSet { applyMuteState() }
    }

    public let store: ConversationStore
    public let settingsStore: SettingsStore

    let audio = AudioCaptureService()
    let vad = VADService()
    let speech = SpeechRecognitionService()
    let camera = CameraService()
    let vision = VisionService()
    let tts = TTSService()
    let hotkeys = HotkeyService()
    let mlx = MLXService.shared

    private var settingsCancellable: AnyCancellable?

    public init(store: ConversationStore? = nil,
                settingsStore: SettingsStore? = nil) {
        self.store = store ?? ConversationStore()
        self.settingsStore = settingsStore ?? SettingsStore()

        audio.delegate = vad
        vad.delegate = self
        tts.delegate = self

        applySettings(self.settingsStore.settings)
        settingsCancellable = self.settingsStore.$settings.sink { [weak self] new in
            self?.applySettings(new)
        }

        wireHotkeys()
    }

    // MARK: Lifecycle

    public func start() async {
        let speechAuth = await speech.requestAuthorization()
        guard speechAuth == .authorized else {
            state = .error("Speech recognition denied")
            return
        }
        let camAuth = await camera.requestAuthorization()
        if settingsStore.settings.cameraEnabled, camAuth {
            do { try camera.start() } catch {
                // Camera failure is soft — Jeff still answers without vision.
            }
        }
        do {
            try audio.start()
            state = isMuted ? .muted : .idle
        } catch {
            state = .error("Could not start microphone: \(error.localizedDescription)")
        }
    }

    public func stop() {
        audio.stop()
        camera.stop()
        tts.interrupt()
    }

    public func toggleMute() {
        isMuted.toggle()
    }

    public func interruptSpeech() {
        if tts.isSpeaking {
            tts.interrupt()
        }
    }

    public func openSettingsRequested(_ block: @escaping () -> Void) {
        openSettingsCallback = block
    }

    private var openSettingsCallback: (() -> Void)?

    // MARK: Settings

    private func applySettings(_ s: JeffSettings) {
        vad.energyThreshold = s.vadSensitivity.energyThreshold
        vad.silenceTimeout = s.silenceTimeoutSeconds

        tts.voiceIdentifier = s.ttsVoiceIdentifier
        tts.rate = s.ttsRate
        tts.volume = s.ttsVolume

        camera.preferredDeviceID = s.cameraDeviceID
        if s.cameraEnabled {
            try? camera.start()
        } else {
            camera.stop()
        }

        // Re-register hotkeys to match current bindings.
        hotkeys.register(action: .mute, hotkey: s.muteHotkey)
        hotkeys.register(action: .interrupt, hotkey: s.interruptHotkey)
        hotkeys.register(action: .openSettings, hotkey: s.openSettingsHotkey)
        hotkeys.register(action: .pushToTalk, hotkey: s.pushToTalkHotkey)
    }

    private func applyMuteState() {
        if isMuted {
            vad.enabled = false
            tts.interrupt()
            state = .muted
        } else {
            vad.enabled = true
            if state == .muted { state = .idle }
        }
    }

    private func wireHotkeys() {
        hotkeys.setCallback(for: .mute) { [weak self] in self?.toggleMute() }
        hotkeys.setCallback(for: .interrupt) { [weak self] in self?.interruptSpeech() }
        hotkeys.setCallback(for: .openSettings) { [weak self] in
            self?.openSettingsCallback?()
        }
        hotkeys.setCallback(for: .pushToTalk) { [weak self] in
            // For simplicity, push-to-talk acts as a momentary unmute trigger.
            // A press-and-hold flow would need NSEvent local monitors; left as
            // a follow-up.
            self?.isMuted = false
        }
    }

    // MARK: Pipeline

    private func handleSpeech(buffers: [AVAudioPCMBuffer]) {
        guard !isMuted else { return }
        let frame = camera.captureStillFrame()
        Task { await runPipeline(buffers: buffers, frame: frame) }
    }

    private func runPipeline(buffers: [AVAudioPCMBuffer], frame: CGImage?) async {
        state = .thinking

        // 1. Transcribe.
        let question: String
        do {
            question = try await speech.transcribe(buffers: buffers)
        } catch {
            state = .error("Could not transcribe: \(error.localizedDescription)")
            await Task.sleep(seconds: 1.5)
            state = isMuted ? .muted : .idle
            return
        }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = isMuted ? .muted : .idle
            return
        }
        lastQuestion = trimmed

        // 2. Describe scene.
        var scene: VisionService.SceneDescription? = nil
        if let frame, settingsStore.settings.cameraEnabled {
            scene = try? await vision.describe(image: frame)
        }

        // 3. Build prompt.
        let history = store.recent(limit: settingsStore.settings.memoryDepth)
        let builder = ContextBuilder(settings: settingsStore.settings)
        let messages = builder.build(history: history, question: trimmed, scene: scene)

        // 4. Generate response.
        let answer: String
        do {
            try await mlx.ensureLoaded(modelPath: settingsStore.settings.modelPath)
            answer = try await mlx.generate(messages: messages)
        } catch {
            state = .error("Model error: \(error.localizedDescription)")
            await Task.sleep(seconds: 2.0)
            state = isMuted ? .muted : .idle
            return
        }
        lastAnswer = answer

        // 5. Speak + record turn.
        store.append(ConversationTurn(
            userText: trimmed,
            assistantText: answer,
            sceneDescription: scene?.summary
        ))
        state = .speaking
        tts.speak(answer)
    }
}

extension PipelineCoordinator: VADDelegate {
    public nonisolated func vadDidDetectSpeechStart(_ vad: VADService) {
        Task { @MainActor in
            if !self.isMuted, !self.tts.isSpeaking {
                self.state = .listening
            }
        }
    }

    public nonisolated func vadDidDetectSpeechEnd(_ vad: VADService, capturedAudio: [AVAudioPCMBuffer]) {
        Task { @MainActor in
            self.handleSpeech(buffers: capturedAudio)
        }
    }
}

extension PipelineCoordinator: TTSServiceDelegate {
    public nonisolated func ttsDidStart(_ service: TTSService) {
        Task { @MainActor in self.state = .speaking }
    }
    public nonisolated func ttsDidFinish(_ service: TTSService) {
        Task { @MainActor in self.state = self.isMuted ? .muted : .idle }
    }
    public nonisolated func ttsDidCancel(_ service: TTSService) {
        Task { @MainActor in self.state = self.isMuted ? .muted : .idle }
    }
}

private extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async {
        try? await Task<Never, Never>.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
