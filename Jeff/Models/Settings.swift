import Foundation
import AppKit

public enum VADSensitivity: String, CaseIterable, Codable, Sendable {
    case low, medium, high

    public var energyThreshold: Float {
        switch self {
        case .low: return 0.020
        case .medium: return 0.012
        case .high: return 0.006
        }
    }
}

public enum ResponseStyle: String, CaseIterable, Codable, Sendable {
    case concise, balanced, detailed

    public var promptHint: String {
        switch self {
        case .concise: return "Answer in one or two short sentences."
        case .balanced: return "Answer clearly and directly without rambling."
        case .detailed: return "Answer thoroughly with relevant detail."
        }
    }
}

public struct Hotkey: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: UInt32
    public var enabled: Bool

    public init(keyCode: UInt16, modifiers: UInt32, enabled: Bool) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.enabled = enabled
    }

    public static let disabled = Hotkey(keyCode: 0, modifiers: 0, enabled: false)
}

/// User-configurable settings. Persisted to UserDefaults on change.
public struct JeffSettings: Codable, Equatable, Sendable {
    // Activation
    public var vadSensitivity: VADSensitivity
    public var silenceTimeoutSeconds: Double
    public var pushToTalkHotkey: Hotkey

    // Hotkeys
    public var muteHotkey: Hotkey
    public var interruptHotkey: Hotkey
    public var openSettingsHotkey: Hotkey

    // Voice
    public var ttsVoiceIdentifier: String?
    public var ttsRate: Float
    public var ttsVolume: Float

    // Camera
    public var cameraEnabled: Bool
    public var cameraDeviceID: String?
    public var showCameraPreview: Bool

    // Assistant
    public var memoryDepth: Int
    public var systemPrompt: String
    public var responseStyle: ResponseStyle

    // Model
    public var modelPath: String?
    public var inferenceThreads: Int  // 0 means auto

    public static let defaults = JeffSettings(
        vadSensitivity: .medium,
        silenceTimeoutSeconds: 1.5,
        pushToTalkHotkey: .disabled,
        muteHotkey: Hotkey(keyCode: 46, modifiers: 0x100000 | 0x080000, enabled: true), // ⌘⌥M
        interruptHotkey: Hotkey(keyCode: 53, modifiers: 0, enabled: true), // Esc
        openSettingsHotkey: Hotkey(keyCode: 43, modifiers: 0x100000, enabled: true), // ⌘,
        ttsVoiceIdentifier: nil,
        ttsRate: 0.5,
        ttsVolume: 1.0,
        cameraEnabled: true,
        cameraDeviceID: nil,
        showCameraPreview: true,
        memoryDepth: 5,
        systemPrompt: "You are Jeff, a friendly personal assistant. You can see what is in front of the user via their camera. Be honest and concise.",
        responseStyle: .balanced,
        modelPath: nil,
        inferenceThreads: 0
    )
}

@MainActor
public final class SettingsStore: ObservableObject {
    @Published public var settings: JeffSettings {
        didSet { persist() }
    }

    private let key = "JeffSettings.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(JeffSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .defaults
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
