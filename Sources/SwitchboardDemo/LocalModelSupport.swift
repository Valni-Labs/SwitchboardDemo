import Foundation
import Switchboard
import SwitchboardLocal

@MainActor
enum LocalModelSupport {
    nonisolated static let wireFormat = "on-device"

    static let models: [LocalModel] = [
        LocalModel(
            huggingFaceRepoID: "mlx-community/Qwen2.5-3B-Instruct-4bit",
            displayName: "Qwen 2.5 3B (on this Mac)"
        ),
        LocalModel(
            huggingFaceRepoID: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            displayName: "Llama 3.2 1B (on this Mac)"
        ),
    ]

    static var options: [ModelOption] {
        models.map { localModel in
            ModelOption(
                id: localModel.id,
                displayName: localModel.displayName,
                wireFormat: wireFormat,
                contextWindow: ModelLimits.localDefault.contextWindow
            )
        }
    }

    enum LocalModelError: LocalizedError {
        case unknownModel(String)
        case notReady(String)

        var errorDescription: String? {
            switch self {
            case .unknownModel(let id):
                "No on-device model registered for '\(id)'."
            case .notReady(let message):
                "The on-device model could not be prepared: \(message)"
            }
        }
    }

    nonisolated static func streamReply(modelID: String, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                guard let localModel = models.first(where: { $0.id == modelID }) else {
                    continuation.finish(throwing: LocalModelError.unknownModel(modelID))
                    return
                }
                do {
                    try await ensureReady(localModel)
                    let messages = history.map { entry in
                        ChatMessage(role: entry.role == .user ? .user : .assistant, text: entry.text)
                    }
                    for try await chunk in localModel.provider.generateRaw(messages: messages) {
                        if case .text(let piece) = chunk, !piece.isEmpty {
                            continuation.yield(piece)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { @MainActor in
                    models.first(where: { $0.id == modelID })?.provider.abort()
                }
            }
        }
    }

    private static func ensureReady(_ localModel: LocalModel) async throws {
        switch localModel.state {
        case .ready:
            return
        case .notDownloaded, .failed:
            localModel.download()
        case .downloaded:
            await localModel.load()
        case .downloading, .loading:
            break
        }
        while true {
            switch localModel.state {
            case .ready:
                return
            case .failed(let message):
                throw LocalModelError.notReady(message)
            case .notDownloaded, .downloaded, .downloading, .loading:
                try await Task.sleep(for: .milliseconds(200))
            }
        }
    }
}

final class HybridModelCatalog: ModelCatalogProviding {
    private let cloud: any ModelCatalogProviding

    init(cloud: any ModelCatalogProviding) {
        self.cloud = cloud
    }

    func loadModels(applicationKey: String) async throws -> [ModelOption] {
        let localOptions = await LocalModelSupport.options
        guard !applicationKey.isEmpty else { return localOptions }
        return try await localOptions + cloud.loadModels(applicationKey: applicationKey)
    }
}

final class HybridChatService: ChatStreaming {
    private let cloud: any ChatStreaming

    init(cloud: any ChatStreaming) {
        self.cloud = cloud
    }

    func streamReply(
        model: ModelOption,
        applicationKey: String,
        endUserKey: String?,
        history: [TranscriptEntry]
    ) -> AsyncThrowingStream<String, Error> {
        guard model.wireFormat == LocalModelSupport.wireFormat else {
            return cloud.streamReply(
                model: model,
                applicationKey: applicationKey,
                endUserKey: endUserKey,
                history: history
            )
        }
        return LocalModelSupport.streamReply(modelID: model.id, history: history)
    }
}
