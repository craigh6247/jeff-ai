import Foundation

/// A single round-trip exchange between the user and Jeff. Stored only for the
/// duration of a session — v1 has no on-disk persistence.
public struct ConversationTurn: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let userText: String
    public let assistantText: String
    public let sceneDescription: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        userText: String,
        assistantText: String,
        sceneDescription: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.userText = userText
        self.assistantText = assistantText
        self.sceneDescription = sceneDescription
    }
}
