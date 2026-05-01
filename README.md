# My Name is Jeff

A fully offline macOS voice assistant that sees through your camera and answers
your questions out loud. Apple Silicon, no network, no telemetry.

## What's in this repo

```
Jeff/
├── JeffApp.swift          # @main app entry
├── ContentView.swift      # main window
├── Info.plist             # mic / camera / speech usage strings
├── Jeff.entitlements      # sandbox + device entitlements
├── Models/                # AppState, ConversationTurn, Settings
├── Services/              # audio, VAD, speech, camera, vision, MLX, TTS, hotkeys, pipeline
└── Views/                 # status indicator, transcript, camera preview, settings
Package.swift              # builds the pure-Swift core as a library (CI-friendly)
```

The non-UI logic in `Jeff/Models` and `Jeff/Services` is exposed as the
`JeffCore` Swift Package product. The shipping app is an Xcode project that
references the same source tree and adds the SwiftUI views, Info.plist, and
entitlements.

## Build the app (one-time setup on macOS)

1. Open Xcode 15+, **File → New → Project → macOS App**, name it `Jeff`,
   interface SwiftUI, language Swift, organization identifier of your choice.
2. Delete the auto-generated `JeffApp.swift` and `ContentView.swift`.
3. Right-click the project, **Add Files to "Jeff"…**, select the `Jeff/`
   folder from this repo and add it as folder reference (or by groups).
4. In **Signing & Capabilities**:
   - Set your team.
   - Add capabilities: **App Sandbox** (with **Camera**, **Audio Input**,
     **User Selected File**) and **Hardened Runtime**.
   - Replace the auto-generated entitlements with `Jeff/Jeff.entitlements`.
5. Set the project's `Info.plist` file to `Jeff/Info.plist`.
6. Set deployment target to macOS 14.0.

### Add MLX (for the local LLM)

In **File → Add Package Dependencies…** add:

- `https://github.com/ml-explore/mlx-swift` (products: `MLX`, `MLXNN`,
  `MLXOptimizers`, `MLXRandom`)
- `https://github.com/ml-explore/mlx-swift-examples` (product: `MLXLLM`,
  `MLXLMCommon`)

`MLXService.swift` is guarded by `#if canImport(MLXLLM)`, so it builds without
those packages and throws `mlxNotAvailable` at runtime. Once the packages are
linked, the real generation path activates automatically.

### Get the model weights

Download a Gemma 4 4B MLX model (or any other MLX-compatible chat model) into a
folder you control, then point **Settings → Model → Model path** at it.

```bash
# example, using huggingface-cli
mkdir -p ~/Models/gemma-4-4b-mlx
huggingface-cli download mlx-community/gemma-4-4b-it-4bit --local-dir ~/Models/gemma-4-4b-mlx
```

### First launch permissions

On first launch macOS will prompt for:

- **Microphone** — VAD + speech capture
- **Camera** — frame capture for visual context
- **Speech Recognition** — `SFSpeechRecognizer` (on-device)
- **Accessibility** — only if you use global hotkeys outside the app's window

All processing is local. Confirm by running Little Snitch or Lulu — Jeff makes
zero network calls.

## Pipeline

```
mic → AudioCaptureService → VADService
                           ├─ on speech-start → state = .listening
                           └─ on speech-end   → buffers
                                              ↓
                          SpeechRecognitionService.transcribe(buffers)
                                              ↓
                          camera.captureStillFrame()
                                              ↓
                          VisionService.describe(image)
                                              ↓
                          ContextBuilder.build(history, question, scene)
                                              ↓
                          MLXService.generate(messages)
                                              ↓
                          TTSService.speak(answer) + ConversationStore.append
```

## Status

This is a v1 scaffold of the spec in PRODUCT_SPEC.md. Pieces that need work
before you can ship:

- [ ] Wire the MLX Swift packages and verify generation against a real model.
- [ ] Replace the energy-based VAD with Silero or WebRTC for fewer false
      positives in noisy environments.
- [ ] Push-to-talk hotkey is currently a momentary unmute trigger; if you want
      true press-and-hold semantics, add an `NSEvent.addGlobalMonitorForEvents`
      keyUp listener.
- [ ] Exercise the full pipeline end-to-end on an M-series Mac and tune the
      response-latency budget.

Out of scope for v1 (per spec): iOS, wake word, internet search, persistent
memory, multilingual, file/screen awareness, multi-user, noise cancellation,
per-app muting.
