import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case system, user, assistant }

    let id = UUID()
    let role: Role
    var content: String
}
