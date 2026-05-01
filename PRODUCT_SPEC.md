# Jeff – Full Product Spec

## One Line
A fully offline macOS voice assistant that sees through your camera and answers your questions out loud.

## Problem
You want a personal AI assistant that is always available, requires no internet, costs nothing per query, and can reason about the physical world in front of you.

## User
Single user. Personal tool. Mac with Apple Silicon.

## Core Experience
Jeff sits quietly in the background. You speak naturally. Jeff listens, looks at what your camera sees, thinks, and speaks back. The entire exchange is private and local.

## Activation
- Always listening via Voice Activity Detection (VAD)
- Monitors microphone continuously at low power
- Speech onset triggers recording automatically
- Silence for 1.5s (configurable) ends the recording and sends to pipeline
- Optional push-to-talk key configurable as override for noisy environments

## Inputs

| Input                | Detail                                             |
|----------------------|----------------------------------------------------|
| Microphone           | Continuous VAD monitoring, buffers on speech onset |
| Camera               | Still frame captured at moment of speech end       |
| Conversation history | Last N turns held in session memory                |
| System context       | Time, date, machine name injected into prompt      |

## Outputs

| Output           | Detail                            |
|------------------|-----------------------------------|
| Voice response   | AVSpeechSynthesizer, spoken aloud |
| Transcript       | Question and answer shown in UI   |
| Status indicator | Clear visual state at all times   |

## Pipeline

```
VAD detects speech
      │
      ▼
Buffer audio until silence
      │
      ├─────────────────────────┐
      ▼                         ▼
SFSpeechRecognizer          CameraService
→ question text             → still frame
      │                         │
      └────────────┬────────────┘
                   ▼
           VisionService
           → scene description
                   │
                   ▼
           ContextBuilder
           → assembled prompt
                   │
                   ▼
           MLXService (Gemma 4 4B)
           → response text
                   │
                   ▼
           AVSpeechSynthesizer
           → spoken aloud
                   │
                   ▼
           ConversationHistory
           → turn stored
```

## Application States

| State     | Indicator                            |
|-----------|--------------------------------------|
| Idle      | Subtle ambient animation             |
| Listening | Active waveform, recording indicator |
| Thinking  | Spinner or pulse                     |
| Speaking  | Waveform synced to TTS output        |
| Muted     | Clear muted badge                    |
| Error     | Brief error message, returns to idle |

## Settings Panel

### Activation
- VAD sensitivity – Low / Medium / High
- Silence timeout – 0.5s to 5.0s slider (default 1.5s)
- Push-to-talk override key – configurable or disabled

### Hotkeys
- Mute / unmute Jeff – configurable key combo
- Interrupt response – configurable key (stops TTS mid-speech)
- Open settings – configurable key combo

### Voice
- TTS voice – any installed macOS system voice
- TTS rate – slider (default normal)
- TTS volume – slider

### Camera
- Enable / disable camera input – toggle
- Camera source – select from available devices
- Show camera preview in window – toggle

### Assistant
- Conversation memory depth – 1 to 10 turns
- System prompt – editable text field (personal context about you)
- Response style – Concise / Balanced / Detailed

### Model
- Model path – file picker (points to local MLX weights)
- Inference threads – auto or manual

## Conversation Memory
- Session-scoped only (v1) – cleared on app quit
- Configurable depth (default last 5 turns)
- Injected into prompt on every request
- No disk persistence in v1

## Permissions Required

| Permission         | Usage                            |
|--------------------|----------------------------------|
| Microphone         | VAD + speech capture             |
| Camera             | Frame capture for visual context |
| Accessibility      | Global hotkey registration       |
| Speech Recognition | SFSpeechRecognizer (on-device)   |

All requested on first launch with plain English explanations.

## System Requirements

| Requirement | Minimum                           |
|-------------|-----------------------------------|
| Hardware    | Apple Silicon (M1 or later)       |
| OS          | macOS 14 Sonoma or later          |
| RAM         | 8GB (16GB recommended)            |
| Storage     | ~3GB for Gemma 4 4B model weights |
| Camera      | Built-in or USB                   |
| Microphone  | Built-in or external              |

## Non-Functional Requirements

| Requirement             | Target                                              |
|-------------------------|-----------------------------------------------------|
| Response latency        | Under 5 seconds for typical query on M2+            |
| VAD false positive rate | Low – should not trigger on background noise        |
| Privacy                 | Zero network calls, zero telemetry                  |
| Stability               | No crashes during continuous all-day use            |
| CPU in idle             | Minimal – VAD should not drain battery meaningfully |

## Out of Scope (v1)
- iOS / iPadOS
- Wake word ("Hey Jeff")
- Internet search or cloud APIs
- Persistent memory across sessions
- Multiple languages
- File, document, or screen awareness
- Multi-user support
- Noise cancellation profiles
- Per-app muting

## Success Criteria for v1
- Jeff correctly transcribes a spoken question
- Jeff describes what the camera sees and incorporates it into the answer
- Jeff speaks the response back within 5 seconds
- Jeff maintains conversational context across at least 3 turns
- All processing confirmed offline via network monitoring
- App runs stably for a full working day without restart
