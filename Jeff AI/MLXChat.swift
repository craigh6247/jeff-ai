import Foundation

#if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
import MLX
import MLXLLM
import MLXLMCommon
#endif

enum MLXChatError: LocalizedError {
    case packagesNotInstalled
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .packagesNotInstalled:
            return "MLX Swift packages aren't installed. In Xcode: File → Add Package Dependencies → https://github.com/ml-explore/mlx-swift-examples — add MLX, MLXLLM, MLXLMCommon to the Jeff AI target."
        case .notLoaded:
            return "Model isn't loaded yet."
        }
    }
}

actor MLXChat {
    struct Message: Sendable {
        enum Role: String, Sendable { case system, user, assistant }
        let role: Role
        let content: String
    }

    #if canImport(MLXLLM) && canImport(MLXLMCommon)
    private var container: ModelContainer?
    #endif
    private var loadedID: String?

    func load(modelID: String) async throws {
        if loadedID == modelID { return }
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        let configuration = ModelConfiguration(id: modelID)
        let factory = LLMModelFactory.shared
        container = try await factory.loadContainer(configuration: configuration)
        loadedID = modelID
        #else
        throw MLXChatError.packagesNotInstalled
        #endif
    }

    func generate(
        messages: [Message],
        maxTokens: Int = 512,
        onChunk: @Sendable @escaping (String) -> Void
    ) async throws {
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        guard let container else { throw MLXChatError.notLoaded }

        let chatMessages: [Chat.Message] = messages.map { m in
            switch m.role {
            case .system:    return .system(m.content)
            case .user:      return .user(m.content)
            case .assistant: return .assistant(m.content)
            }
        }

        try await container.perform { context in
            let input = try await context.processor.prepare(input: .init(chat: chatMessages))
            let parameters = GenerateParameters(temperature: 0.7, topP: 0.95)
            let stream = try MLXLMCommon.generate(
                input: input,
                parameters: parameters,
                context: context
            )
            var tokenCount = 0
            for await item in stream {
                try Task.checkCancellation()
                if case .chunk(let text) = item {
                    onChunk(text)
                    tokenCount += 1
                    if tokenCount >= maxTokens { break }
                }
            }
        }
        #else
        _ = messages
        _ = maxTokens
        _ = onChunk
        throw MLXChatError.packagesNotInstalled
        #endif
    }
}
