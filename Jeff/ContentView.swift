import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: PipelineCoordinator
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 16) {
            HeaderBar()
            StatusIndicatorView()
                .frame(height: 80)

            if settingsStore.settings.cameraEnabled, settingsStore.settings.showCameraPreview {
                CameraPreviewView(session: coordinator.camera.session)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
            }

            TranscriptView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FooterBar()
        }
        .padding(16)
    }
}

private struct HeaderBar: View {
    @EnvironmentObject var coordinator: PipelineCoordinator
    var body: some View {
        HStack {
            Text("Jeff").font(.system(size: 28, weight: .semibold, design: .rounded))
            Spacer()
            Text(coordinator.state.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FooterBar: View {
    @EnvironmentObject var coordinator: PipelineCoordinator
    var body: some View {
        HStack(spacing: 12) {
            Button {
                coordinator.toggleMute()
            } label: {
                Label(coordinator.isMuted ? "Unmute" : "Mute",
                      systemImage: coordinator.isMuted ? "mic.slash.fill" : "mic.fill")
            }
            Button {
                coordinator.interruptSpeech()
            } label: {
                Label("Interrupt", systemImage: "stop.fill")
            }
            .disabled(!coordinator.tts.isSpeaking)
            Spacer()
            Button {
                coordinator.store.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
        }
        .buttonStyle(.bordered)
    }
}
