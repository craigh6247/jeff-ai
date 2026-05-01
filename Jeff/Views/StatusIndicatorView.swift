import SwiftUI

struct StatusIndicatorView: View {
    @EnvironmentObject var coordinator: PipelineCoordinator
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(background)
            content
        }
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private var background: Color {
        switch coordinator.state {
        case .idle: return Color.secondary.opacity(0.08)
        case .listening: return Color.blue.opacity(0.12)
        case .thinking: return Color.purple.opacity(0.12)
        case .speaking: return Color.green.opacity(0.12)
        case .muted: return Color.gray.opacity(0.18)
        case .error: return Color.red.opacity(0.15)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.state {
        case .idle:
            HStack(spacing: 8) {
                Circle().fill(.secondary).frame(width: 8, height: 8)
                Text("Ready").foregroundStyle(.secondary)
            }
        case .listening:
            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    Capsule()
                        .frame(width: 4, height: 12 + CGFloat((i * 7) % 24))
                        .foregroundStyle(.blue)
                        .scaleEffect(y: 0.7 + 0.6 * sin(phase * .pi * 2 + CGFloat(i)))
                }
            }
        case .thinking:
            ProgressView().controlSize(.small)
        case .speaking:
            HStack(spacing: 4) {
                ForEach(0..<7) { i in
                    Capsule()
                        .frame(width: 3, height: 8 + CGFloat((i * 5) % 22))
                        .foregroundStyle(.green)
                        .scaleEffect(y: 0.5 + 0.5 * sin(phase * .pi * 2 + CGFloat(i) * 0.6))
                }
            }
        case .muted:
            Label("Muted", systemImage: "mic.slash.fill").foregroundStyle(.secondary)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(2)
                .padding(.horizontal, 8)
        }
    }
}
