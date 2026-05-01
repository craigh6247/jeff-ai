import Foundation

#if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
import MLX
import MLXLLM
import MLXLMCommon
#endif

public enum MLXServiceError: Error {
    case modelPathMissing
    case modelLoadFailed(String)
    case generationFailed(String)
    case mlxNotAvailable
}

public struct LLMMessage: Sendable {
    public enum Role: String, Sendable { case system, user, assistant }
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// Local MLX-backed language model service. The integration with MLX is
/// guarded by `#if canImport(MLXLLM)` so this file compiles even before the
/// MLX Swift packages are added — the service simply throws
/// `mlxNotAvailable`. Once the packages are added in Xcode, the real path
/// activates automatically.
public actor MLXService {
    public static let shared = MLXService()

    private var loadedModelPath: String?

    #if canImport(MLXLLM) && canImport(MLXLMCommon)
    private var modelContainer: ModelContainer?
    #endif

    public init() {}

    public func ensureLoaded(modelPath: String?) async throws {
        guard let modelPath, !modelPath.isEmpty else {
            throw MLXServiceError.modelPathMissing
        }
        if loadedModelPath == modelPath { return }

        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        do {
            let configuration = ModelConfiguration(directory: URL(fileURLWithPath: modelPath))
            let factory = LLMModelFactory.shared
            let container = try await factory.loadContainer(configuration: configuration)
            self.modelContainer = container
            self.loadedModelPath = modelPath
        } catch {
            throw MLXServiceError.modelLoadFailed(error.localizedDescription)
        }
        #else
        throw MLXServiceError.mlxNotAvailable
        #endif
    }

    public func generate(messages: [LLMMessage], maxTokens: Int = 512) async throws -> String {
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        guard let modelContainer else {
            throw MLXServiceError.modelLoadFailed("Model not loaded")
        }
        do {
            let chatMessages: [Chat.Message] = messages.map { msg in
                switch msg.role {
                case .system:    return .system(msg.content)
                case .user:      return .user(msg.content)
                case .assistant: return .assistant(msg.content)
                }
            }
            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(input: .init(messages: chatMessages))
                let parameters = GenerateParameters(temperature: 0.7, topP: 0.95)
                var output = ""
                let stream = try MLXLMCommon.generate(
                    input: input,
                    parameters: parameters,
                    context: context
                )
                var tokenCount = 0
                for await item in stream {
                    if case .chunk(let text) = item {
                        output += text
                        tokenCount += 1
                        if tokenCount >= maxTokens { break }
                    }
                }
                return output
            }
            return result
        } catch {
            throw MLXServiceError.generationFailed(error.localizedDescription)
        }
        #else
        // Compile-time stub so the rest of the app builds before the MLX
        // Swift packages are added. The pipeline surfaces this as an error
        // and the UI tells the user to configure the model path.
        _ = messages
        _ = maxTokens
        throw MLXServiceError.mlxNotAvailable
        #endif
    }
}
