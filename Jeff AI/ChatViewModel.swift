import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isGenerating: Bool = false
    @Published var modelReady: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var streamingTick: Int = 0

    let modelID: String = "mlx-community/gemma-4-e2b-it-OptiQ-4bit"
    private let systemPrompt = "You are Jeff, a concise and friendly assistant. Answer in plain text."

    private let mlx = MLXChat()
    private var currentTask: Task<Void, Never>?

    func send(_ text: String) async {
        guard !isGenerating else { return }
        messages.append(ChatMessage(role: .user, content: text))
        isGenerating = true
        defer { isGenerating = false }

        if !modelReady {
            do {
                try await mlx.load(modelID: modelID)
                modelReady = true
            } catch {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                return
            }
        }

        let prompt = buildPrompt()
        var assistant = ChatMessage(role: .assistant, content: "")
        messages.append(assistant)
        let assistantIndex = messages.count - 1

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.mlx.generate(messages: prompt) { [weak self] chunk in
                    guard let self else { return }
                    Task { @MainActor in
                        guard self.messages.indices.contains(assistantIndex) else { return }
                        self.messages[assistantIndex].content += chunk
                        self.streamingTick &+= 1
                    }
                }
            } catch is CancellationError {
                // Expected on user cancel.
            } catch {
                await MainActor.run {
                    self.errorMessage = "Generation failed: \(error.localizedDescription)"
                    if self.messages.indices.contains(assistantIndex),
                       self.messages[assistantIndex].content.isEmpty {
                        self.messages.remove(at: assistantIndex)
                    }
                }
            }
        }
        currentTask = task
        await task.value
        _ = assistant
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    private func buildPrompt() -> [MLXChat.Message] {
        var out: [MLXChat.Message] = [.init(role: .system, content: systemPrompt)]
        for m in messages where !m.content.isEmpty {
            switch m.role {
            case .system:    out.append(.init(role: .system, content: m.content))
            case .user:      out.append(.init(role: .user, content: m.content))
            case .assistant: out.append(.init(role: .assistant, content: m.content))
            }
        }
        return out
    }
}
