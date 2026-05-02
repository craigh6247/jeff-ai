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

## Setup status — what's done and what you still have to do

This repo is a **source-only scaffold**, not a build-and-run app. There is
deliberately no `.xcodeproj` checked in (Xcode projects don't merge cleanly and
encode developer-team / signing settings that are personal to each machine).
You generate the project locally on your Mac.

### Done in this repo

- All Swift sources for models, services, and SwiftUI views.
- `Info.plist` with mic / camera / speech usage strings.
- `Jeff.entitlements` with sandbox + device entitlements; network capabilities
  explicitly disabled to enforce the offline guarantee.
- `Package.swift` exposing the non-UI core as `JeffCore` for CI.
- Energy-based VAD that's drop-in replaceable with Silero / WebRTC.
- `MLXService` guarded by `#if canImport(MLXLLM)` so the project compiles
  before the MLX Swift packages are added.

### You still need to do (~30 min on macOS)

1. **Create the Xcode project.** File → New → Project → macOS App, name it
   `Jeff`, SwiftUI, Swift. Delete the auto-generated `JeffApp.swift` and
   `ContentView.swift`.
2. **Add the source tree.** Right-click the project → Add Files to "Jeff"…
   → pick the `Jeff/` folder from this repo (folder reference is fine).
3. **Wire Info.plist + entitlements.** In the target's Build Settings set
   `INFOPLIST_FILE = Jeff/Info.plist` and `CODE_SIGN_ENTITLEMENTS =
   Jeff/Jeff.entitlements`. Set the deployment target to macOS 14.0.
4. **Capabilities.** In Signing & Capabilities add **App Sandbox** (Camera,
   Audio Input, User Selected File) and **Hardened Runtime**. Set your team.
5. **Add MLX packages.** File → Add Package Dependencies…
   - `https://github.com/ml-explore/mlx-swift` — link `MLX`, `MLXNN`,
     `MLXOptimizers`, `MLXRandom`.
   - `https://github.com/ml-explore/mlx-swift-examples` — link `MLXLLM`,
     `MLXLMCommon`.
6. **Download model weights.**
   ```bash
   mkdir -p ~/Models/gemma-4-4b-mlx
   huggingface-cli download mlx-community/gemma-4-4b-it-4bit \
     --local-dir ~/Models/gemma-4-4b-mlx
   ```
   Then in Jeff: Settings → Model → choose that folder.
7. **First launch.** macOS will prompt for Microphone, Camera, and Speech
   Recognition. All on-device.

### Likely small fixes once it actually builds

- The MLX call sites in `Jeff/Services/MLXService.swift`
  (`ModelConfiguration(directory:)`, `LLMModelFactory.shared.loadContainer`,
  `Chat.Message`, the `MLXLMCommon.generate` stream loop) target a recent
  shape of `mlx-swift-examples`, but that API has been moving. Expect to
  rename a few symbols.
- A handful of SwiftUI 14 deprecation warnings (single-arg `.onChange`).
  Non-blocking.
- These sources have **not been compiled** (this scaffold was authored on
  Linux). There may be small Swift 5.9 / actor-isolation issues to clean up
  on first build.

### Behavioral gaps still to close

- **VAD:** energy heuristic will trip on background noise. Production wants
  Silero or WebRTC — only `VADService.evaluate(buffer:)` needs new internals.
- **Push-to-talk:** currently a momentary unmute trigger. True press-and-hold
  needs an `NSEvent.addGlobalMonitorForEvents` keyUp listener.
- **Privacy verification:** confirm zero network egress with Little Snitch or
  Lulu before declaring v1 done.

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

## Out of scope for v1

Per spec: iOS, wake word ("Hey Jeff"), internet search, persistent memory,
multilingual, file/screen awareness, multi-user, noise cancellation, per-app
muting. See `PRODUCT_SPEC.md` for the full list.
