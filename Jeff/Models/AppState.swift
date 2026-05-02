import Foundation

/// High-level state of the assistant. Drives the status indicator and gates
/// transitions in `PipelineCoordinator`.
public enum AppState: Equatable, Sendable {
    case idle
    case listening
    case thinking
    case speaking
    case muted
    case error(String)

    public var isBusy: Bool {
        switch self {
        case .thinking, .speaking: return true
        default: return false
        }
    }

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .listening: return "Listening"
        case .thinking: return "Thinking"
        case .speaking: return "Speaking"
        case .muted: return "Muted"
        case .error: return "Error"
        }
    }
}
