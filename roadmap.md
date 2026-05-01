# Jeff Roadmap

`PRODUCT_SPEC.md` describes v1: the always-on, fully-offline voice + vision
assistant. This document tracks what comes after v1, in the rough order Craig
has prioritized. It is a living file — milestones get rewritten as they land
or as priorities shift.

## Guiding principles

- **Offline by default.** Network access is opt-in per integration, never
  blanket. The sandbox keeps `network.client = false` until a feature
  explicitly needs it, and even then individual destinations are allowlisted.
- **Human in the loop for action.** Jeff can autonomously decide to call a
  tool, but any tool that writes, sends, or modifies state requires explicit
  approval before it runs. Approvals are visible in the transcript.
- **Recognition is generic.** The gallery isn't people-specific — it stores
  embeddings + labels for any thing Jeff is taught (a person, a pet, a tool,
  a room).
- **Encryption is a later sweep, not a blocker.** Persistence ships first
  (gallery, agent workspace), then a single milestone wraps the at-rest data
  with a Keychain-managed key. Don't gate features on this.
- **Acceptance criteria are demoable.** Each milestone lists user-visible
  outcomes, not implementation tasks.

---

## Milestone 1 — Recognition (people, things, places)

### Goal

Jeff can be taught what something is, then identify it on sight. Default
behavior on a new face: "Hi, I'm Jeff — who are you?"

### Features

- **Gallery store.** On-disk file holding `{label, embedding, thumbnail,
  enrolledAt, kind}` records. Plain files in v1; encryption deferred.
- **Voice enrollment.** "Jeff, this is Sam" → Jeff snapshots the current
  salient subject from the camera, embeds it, stores it under that label,
  confirms by speaking back.
- **Image enrollment.** Settings → Gallery → import labeled photos. Bulk
  import (drop a folder of `Sam/*.jpg`) supported.
- **Recognition pipeline.** Per-sample: detect → embed → nearest-neighbor
  against gallery → confidence threshold. Below threshold → "I think that's
  Sam, but I'm not sure."
- **Introduce-yourself behavior.** When an unrecognized face appears
  mid-conversation, Jeff says "Hi, I'm Jeff — who are you?" exactly once per
  unknown identity per session, then offers to enroll on the user's reply.
- **Generic kinds.** Same pipeline used for objects ("This is my keyboard")
  and places ("This is the kitchen"). Kind hints which embedding model is
  used.

### Acceptance criteria

- Voice-enroll a face; Jeff names them on the next turn within the same
  session.
- Photo-enroll a face; Jeff names them when they walk into frame.
- Unknown face triggers the introduction flow once per unknown identity per
  session.
- Photo-enroll an object ("my coffee mug"); Jeff names it when shown later.
- Gallery survives app quit.

### Depends on

Existing `CameraService` + `VisionService`. New: face / object embedding
model, gallery persistence layer.

### Open questions

- People-quality face embeddings need a dedicated model (FaceNet / ArcFace
  exported to Core ML). General objects can probably ride on Apple's
  `VNGenerateImageFeaturePrintRequest`.
- Default confidence threshold needs empirical tuning per kind.

---

## Milestone 2 — Agent harness

### Goal

Jeff runs a multi-turn loop: think → call a tool → observe the result →
think again. Side-effecting tools require approval. Tool calls render in
the transcript with name, args, result, and elapsed time.

### Features

- **Tool protocol.** Each tool declares `{name, jsonSchema, sideEffect:
  pure | filesystem | network | system, requiresApproval: Bool}`. The agent
  loop uses the model's native tool-calling where available, falls back to a
  structured prompt + parser otherwise.
- **Built-in tools (v0).**
  - `workspace.write(path, content)` — write inside the configured workspace
    (`requiresApproval: true`).
  - `workspace.read(path)` — read inside the configured workspace
    (`requiresApproval: false`).
  - `workspace.list(dir)` — directory listing inside the workspace.
  - `web.fetch(url)` — HTTP GET, allowlisted hosts only
    (`requiresApproval: true` unless host is on the always-allow list).
  - `web.search(query)` — wraps a configured search backend (e.g. a local
    SearXNG instance URL set in settings).
- **Approval UI.** Side-effecting tools surface a card in the transcript
  with **Approve / Deny / Always allow this session**. TTS pauses while the
  prompt is open and resumes when it's resolved. Keyboard shortcuts (⌘⏎ /
  ⌘⌫) for quick decisions.
- **Transcript rendering.** Tool calls render as inline cards: tool name,
  pretty-printed args, result preview (collapsible if long), elapsed time,
  status badge (running / approved / denied / error).
- **Multi-turn loop.** Tool result feeds back into the model as a tool
  message; loop continues until the model emits a final answer or hits a
  turn cap (default 6, configurable).
- **Workspace setting.** Default `~/Jeff/workspace`. Settings → Agent →
  workspace folder picker.
- **Network setting.** Settings → Agent → enable network tools (default
  off); allowlist of hostnames; per-request override.

### Acceptance criteria

- "Jeff, summarize the latest entry in my journal" → Jeff calls
  `workspace.list` and `workspace.read`, both visible in transcript, then
  speaks the summary.
- "Jeff, save what you just said to `notes/foo.md`" → approval card
  appears; approving writes the file; transcript shows the result.
- Denying a tool call shows a denial badge and the agent continues
  gracefully (acknowledges the denial in its next message).
- With network disabled, `web.fetch` is not exposed to the model and any
  attempt to invoke it errors with "network tools disabled."
- Sandbox stays `network.client = false` when network tools are disabled.

### Depends on

MLX integration finalized in v1. The model must either support native tool
calls (Gemma's function-calling format, or whatever model gets used) or
reliably emit parsable structured output.

### Open questions

- Approval UX when Jeff is mid-speech — current plan: hard-pause TTS, show
  the card, resume on decision.
- Long-running tools need a cancellation affordance.
- Whether `web.search` should be a single tool that wraps any configured
  backend, or per-backend tools the user enables.

---

## Milestone 3 — Continuous perception

### Goal

Jeff isn't only looking at speech-end — he samples the camera continuously,
runs lightweight scene + recognition analysis, and feeds that into prompt
context. Scene changes become events Jeff can reference.

### Features

- **Sampled frame loop.** Configurable rate (default 1 fps). Each sample
  runs `VisionService.describe` plus the M1 recognition pipeline.
- **Change detection.** Perceptual-hash diff between consecutive samples;
  the heavy recognition pass only runs on meaningful changes to keep CPU
  usage down.
- **Scene memory.** Rolling buffer of the last N scene descriptions, each
  timestamped. Injected into the prompt alongside the current scene.
- **Recognition events.** When the loop detects an enrolled person/object
  entering frame, that lands in scene memory as a structured event ("Sam
  entered frame at 14:32"); combined with M1's introduction flow for
  unknowns.
- **Privacy controls.** Sampling pauses when Jeff is muted, when the camera
  preview is explicitly hidden (settings toggle), and when the screen is
  locked.

### Acceptance criteria

- Walk into frame, ask a question five seconds later — Jeff's answer can
  reference "I noticed you came in" without being explicitly told.
- CPU usage with sampling at 1 fps stays under a documented budget on M2.
- Disabling the camera in settings shuts down the sampling loop within one
  sample interval.
- Scene events older than the configured window are evicted.

### Depends on

M1 recognition pipeline.

### Open questions

- Right sampling rate vs. battery cost — needs measurement on M-series.
- Scene-buffer eviction policy: turn-based (last N conversational turns) or
  time-based (last 60s)? Probably both, with whichever fires first.

---

## Milestone 4 — Basic chat GUI

### Goal

Reshape the existing window into a chat-style transcript that renders
agent activity (tool calls, approvals) and recognition events inline. No
sidebars, no timeline, no separate dashboard — just a clean conversation
view that's pleasant to use day-to-day. Anything richer is a later
milestone if it earns its way in.

### Features

- **Chat-style transcript.** User and Jeff turns rendered as bubbles;
  scrollback with sensible spacing.
- **Inline tool call cards.** Tool name, args, result preview, status
  badge, elapsed time. Long results collapsed by default.
- **Inline approval cards.** M2 approval prompts render in-line in the
  transcript with Approve / Deny buttons + keyboard shortcuts.
- **Inline recognition badges.** When the M3 loop or a turn surfaces a
  recognition event ("Sam entered frame"), it shows as a small
  contextual marker in the transcript.
- **Gallery management surface.** A simple list view in Settings →
  Gallery: label, thumbnail, kind, delete. Drag-and-drop add.

### Acceptance criteria

- Tool calls always render inline; long results collapsible.
- Approvals can be triggered, approved, and denied via mouse and
  keyboard (⌘⏎ approve, ⌘⌫ deny).
- Recognition events appear in the transcript at the moment they fire.
- Gallery edits in Settings take effect without restarting the app.

### Depends on

M1, M2, M3 — this milestone is UI assembly over the foundations.

### Out of scope (deferred until earned)

Activity timeline sidebar, dashboard window, menu-bar HUD, floating
always-on-top overlay, multi-window support.

---

## Milestone 5 — Live recognition overlay

### Goal

The camera preview becomes a live, labeled view: bounding boxes around
detected people / objects with their names overlaid, updated in real
time. Same gallery as M1 — anything Jeff knows gets labeled, anything
he doesn't gets a "?" box that the introduce-yourself flow can resolve.

### Features

- **Detection + tracking.** Per-frame: cheap detection (Vision's face
  detector or saliency for objects) feeds a tracker
  (`VNTrackObjectRequest` or equivalent) so identity persists across
  frames between heavier embedding passes. Embeddings re-run only every
  N frames or on significant pose change.
- **Labeled overlay.** SwiftUI / Core Animation layer over
  `CameraPreviewView` drawing rounded boxes + name pills. Boxes
  smoothed to avoid jitter.
- **Confidence treatment.** High confidence → name shown plain; low
  confidence → name with a "?" suffix; unrecognized → "?" only, with a
  subtle hint that voice-enrolling will name them.
- **Performance budget.** Target 15–30 fps for the overlay layer (not
  necessarily for embedding) on M2. Tracker handles the in-between
  frames so we don't pay embedding cost per frame.
- **Toggle.** Settings → Camera → "Show live recognition overlay"
  on/off. Off by default until the perf budget is verified.
- **Privacy parity.** Overlay sampling pauses when Jeff is muted,
  camera preview is hidden, or screen is locked (same gates as M3).

### Acceptance criteria

- With three enrolled people in frame, all three are labeled and the
  labels stay correct as they move.
- An unenrolled person shows a "?" box; voice-enrolling them updates
  the label live without a restart.
- Overlay frame rate stays at ≥15 fps on an M2 with a 1080p webcam.
- Toggling the overlay off shuts down the detection/tracker work
  within one frame interval.

### Depends on

M1 (gallery + embeddings) and the camera infrastructure already in
place. Borrows M3's privacy gating but doesn't otherwise depend on it
— the overlay loop runs at its own rate independent of the
prompt-context sampling.

### Open questions

- Whether to share one detection pass between M3 (prompt context) and
  M5 (overlay) or keep them as independent loops at different rates.
  Sharing is more efficient; independent loops are simpler.
- Whether long-distance / partial-occlusion re-identification belongs
  here or in a follow-up. v1 of M5 can drop tracking when the subject
  leaves frame and re-acquire by embedding when they return.

---

## Cross-cutting / later

- **Encryption pass.** Wrap gallery + any persisted transcript / activity
  log with a Keychain-stored key. Schedule once M1–M4 are landed but before
  Jeff is used as a daily driver.
- **Persistent conversation memory.** Currently session-only per v1 spec.
  Once recognition + encryption are in, persistent memory becomes useful;
  scope it explicitly when we get there.
- **Multi-session.** Explicitly deferred per Craig.
- **External stream sources.** RTSP / screen capture / video files — not
  scoped yet; will get its own roadmap entry if it ever becomes a priority.

---

## Working agreements

- Each milestone lands as its own PR sequence. M1 is broken into "gallery +
  persistence" → "voice enrollment" → "image enrollment" → "introduce
  yourself" sub-PRs.
- Acceptance criteria are exercised manually on an M-series Mac before a
  milestone is called done. There is no automated CI for the
  SwiftUI/Vision/MLX layer.
- Privacy regression check: every milestone ends with a Little Snitch /
  Lulu run to confirm zero unexpected egress with default settings.
- Open questions in the roadmap are ground truth — when one is resolved, it
  graduates into a feature bullet or moves out of the milestone entirely.
