import SwiftUI

struct TranscriptView: View {
    @EnvironmentObject var store: ConversationStore
    @EnvironmentObject var coordinator: PipelineCoordinator

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.turns) { turn in
                        TurnRow(turn: turn).id(turn.id)
                    }
                    if !coordinator.lastQuestion.isEmpty,
                       store.turns.last?.userText != coordinator.lastQuestion {
                        TurnRow(turn: ConversationTurn(
                            userText: coordinator.lastQuestion,
                            assistantText: coordinator.lastAnswer,
                            sceneDescription: nil
                        ))
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: store.turns.count) { _ in
                if let last = store.turns.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}

private struct TurnRow: View {
    let turn: ConversationTurn

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("You", systemImage: "person.fill")
                .font(.caption).foregroundStyle(.secondary)
            Text(turn.userText)
                .padding(10)
                .background(Color.blue.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Label("Jeff", systemImage: "sparkles")
                .font(.caption).foregroundStyle(.secondary)
            Text(turn.assistantText)
                .padding(10)
                .background(Color.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if let scene = turn.sceneDescription, !scene.isEmpty {
                Text(scene)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
