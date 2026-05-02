import Foundation
import Combine

/// In-memory conversation history. Cleared on app quit per v1 spec.
@MainActor
public final class ConversationStore: ObservableObject {
    @Published public private(set) var turns: [ConversationTurn] = []

    public init() {}

    public func append(_ turn: ConversationTurn) {
        turns.append(turn)
    }

    public func clear() {
        turns.removeAll()
    }

    public func recent(limit: Int) -> [ConversationTurn] {
        Array(turns.suffix(max(0, limit)))
    }
}
