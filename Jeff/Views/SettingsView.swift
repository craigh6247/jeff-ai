import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            ActivationSettings().tabItem { Label("Activation", systemImage: "waveform") }
            HotkeySettings().tabItem { Label("Hotkeys", systemImage: "command") }
            VoiceSettings().tabItem { Label("Voice", systemImage: "speaker.wave.2") }
            CameraSettings().tabItem { Label("Camera", systemImage: "camera") }
            AssistantSettings().tabItem { Label("Assistant", systemImage: "brain") }
            ModelSettings().tabItem { Label("Model", systemImage: "cpu") }
        }
        .frame(width: 520, height: 380)
        .padding(20)
    }
}

private struct ActivationSettings: View {
    @EnvironmentObject var store: SettingsStore
    var body: some View {
        Form {
            Picker("VAD sensitivity", selection: $store.settings.vadSensitivity) {
                Text("Low").tag(VADSensitivity.low)
                Text("Medium").tag(VADSensitivity.medium)
                Text("High").tag(VADSensitivity.high)
            }
            HStack {
                Text("Silence timeout")
                Slider(value: $store.settings.silenceTimeoutSeconds, in: 0.5...5.0, step: 0.1)
                Text("\(store.settings.silenceTimeoutSeconds, specifier: "%.1f")s").monospacedDigit()
            }
            HotkeyField(label: "Push-to-talk override", binding: $store.settings.pushToTalkHotkey)
        }
    }
}

private struct HotkeySettings: View {
    @EnvironmentObject var store: SettingsStore
    var body: some View {
        Form {
            HotkeyField(label: "Mute / unmute Jeff", binding: $store.settings.muteHotkey)
            HotkeyField(label: "Interrupt response", binding: $store.settings.interruptHotkey)
            HotkeyField(label: "Open settings", binding: $store.settings.openSettingsHotkey)
        }
    }
}

private struct VoiceSettings: View {
    @EnvironmentObject var store: SettingsStore
    var body: some View {
        Form {
            Picker("TTS voice", selection: Binding(
                get: { store.settings.ttsVoiceIdentifier ?? "" },
                set: { store.settings.ttsVoiceIdentifier = $0.isEmpty ? nil : $0 }
            )) {
                Text("System default").tag("")
                ForEach(TTSService.availableVoices(), id: \.identifier) { voice in
                    Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                }
            }
            HStack {
                Text("Rate")
                Slider(value: $store.settings.ttsRate,
                       in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
            }
            HStack {
                Text("Volume")
                Slider(value: $store.settings.ttsVolume, in: 0...1)
            }
        }
    }
}

private struct CameraSettings: View {
    @EnvironmentObject var store: SettingsStore
    var body: some View {
        Form {
            Toggle("Enable camera input", isOn: $store.settings.cameraEnabled)
            Toggle("Show camera preview", isOn: $store.settings.showCameraPreview)
                .disabled(!store.settings.cameraEnabled)
            Picker("Camera source", selection: Binding(
                get: { store.settings.cameraDeviceID ?? "" },
                set: { store.settings.cameraDeviceID = $0.isEmpty ? nil : $0 }
            )) {
                Text("System default").tag("")
                ForEach(availableCameras(), id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device.uniqueID)
                }
            }
            .disabled(!store.settings.cameraEnabled)
        }
    }

    private func availableCameras() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .deskViewCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }
}

private struct AssistantSettings: View {
    @EnvironmentObject var store: SettingsStore
    var body: some View {
        Form {
            Stepper("Conversation memory: \(store.settings.memoryDepth) turns",
                    value: $store.settings.memoryDepth, in: 1...10)
            VStack(alignment: .leading) {
                Text("System prompt").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $store.settings.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 110)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3)))
            }
            Picker("Response style", selection: $store.settings.responseStyle) {
                ForEach(ResponseStyle.allCases, id: \.self) { style in
                    Text(style.rawValue.capitalized).tag(style)
                }
            }
        }
    }
}

private struct ModelSettings: View {
    @EnvironmentObject var store: SettingsStore
    @State private var pickingFile = false
    var body: some View {
        Form {
            HStack {
                Text("Model path")
                Text(store.settings.modelPath ?? "Not set")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose…") { pickingFile = true }
            }
            Stepper(value: $store.settings.inferenceThreads, in: 0...32) {
                if store.settings.inferenceThreads == 0 {
                    Text("Inference threads: auto")
                } else {
                    Text("Inference threads: \(store.settings.inferenceThreads)")
                }
            }
        }
        .fileImporter(
            isPresented: $pickingFile,
            allowedContentTypes: [.folder, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.settings.modelPath = url.path
            }
        }
    }
}

private struct HotkeyField: View {
    let label: String
    @Binding var binding: Hotkey

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("Enabled", isOn: $binding.enabled).labelsHidden()
            HotkeyRecorder(hotkey: $binding)
                .frame(width: 160)
        }
    }
}

/// Minimal hotkey recorder. Captures the next key press while focused and
/// stores its keyCode + carbon modifiers.
private struct HotkeyRecorder: NSViewRepresentable {
    @Binding var hotkey: Hotkey

    func makeNSView(context: Context) -> RecorderField {
        let view = RecorderField()
        view.onCapture = { keyCode, mods in
            hotkey.keyCode = keyCode
            hotkey.modifiers = mods
        }
        view.update(hotkey: hotkey)
        return view
    }

    func updateNSView(_ nsView: RecorderField, context: Context) {
        nsView.update(hotkey: hotkey)
    }
}

final class RecorderField: NSTextField {
    var onCapture: ((UInt16, UInt32) -> Void)?
    private var monitor: Any?

    init() {
        super.init(frame: .zero)
        isEditable = false
        isBezeled = true
        bezelStyle = .roundedBezel
        alignment = .center
        focusRingType = .default
        stringValue = "—"
    }
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok, monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let mods = Self.carbonModifiers(from: event.modifierFlags)
                self.onCapture?(event.keyCode, mods)
                self.window?.makeFirstResponder(nil)
                return nil
            }
        }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        return super.resignFirstResponder()
    }

    func update(hotkey: Hotkey) {
        if !hotkey.enabled || (hotkey.keyCode == 0 && hotkey.modifiers == 0) {
            stringValue = "—"
        } else {
            stringValue = Self.describe(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= 0x100000 }
        if flags.contains(.option)  { m |= 0x080000 }
        if flags.contains(.control) { m |= 0x040000 }
        if flags.contains(.shift)   { m |= 0x020000 }
        return m
    }

    private static func describe(keyCode: UInt16, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & 0x040000 != 0 { parts.append("⌃") }
        if modifiers & 0x080000 != 0 { parts.append("⌥") }
        if modifiers & 0x020000 != 0 { parts.append("⇧") }
        if modifiers & 0x100000 != 0 { parts.append("⌘") }
        parts.append("[\(keyCode)]")
        return parts.joined()
    }
}
