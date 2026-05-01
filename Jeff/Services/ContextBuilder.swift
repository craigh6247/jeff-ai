import Foundation

/// Assembles the full prompt sent to the language model. Pulls together:
///   - User-configured system prompt
///   - Response-style hint
///   - System metadata (time, date, machine name)
///   - Visual scene description (if available)
///   - Last N conversation turns
///   - The current user question
public struct ContextBuilder {
    public var settings: JeffSettings

    public init(settings: JeffSettings) {
        self.settings = settings
    }

    public func build(
        history: [ConversationTurn],
        question: String,
        scene: VisionService.SceneDescription?
    ) -> [LLMMessage] {
        var messages: [LLMMessage] = []
        messages.append(.init(role: .system, content: systemPrompt(scene: scene)))

        let recent = history.suffix(max(0, settings.memoryDepth))
        for turn in recent {
            messages.append(.init(role: .user, content: turn.userText))
            messages.append(.init(role: .assistant, content: turn.assistantText))
        }
        messages.append(.init(role: .user, content: question))
        return messages
    }

    private func systemPrompt(scene: VisionService.SceneDescription?) -> String {
        var lines: [String] = []
        lines.append(settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines))
        lines.append(settings.responseStyle.promptHint)

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        let now = formatter.string(from: Date())
        let host = Host.current().localizedName ?? "this Mac"
        lines.append("Current local time: \(now). Running on \(host).")

        if let scene {
            lines.append("Visual context from the user's camera: \(scene.summary)")
        } else {
            lines.append("No camera input is available right now.")
        }

        return lines.joined(separator: "\n")
    }
}
