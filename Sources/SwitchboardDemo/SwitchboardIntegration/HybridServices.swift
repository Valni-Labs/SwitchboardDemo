import Foundation

final class HybridModelCatalog: ModelCatalogProviding {
    private let store: LocalModelStore
    private let cloud: any ModelCatalogProviding

    init(store: LocalModelStore, cloud: any ModelCatalogProviding) {
        self.store = store
        self.cloud = cloud
    }

    func loadModels(applicationKey: String) async throws -> [ModelOption] {
        let localOptions = await store.pickerOptions
        guard !applicationKey.isEmpty else { return localOptions }
        return try await localOptions + cloud.loadModels(applicationKey: applicationKey)
    }
}

final class HybridChatService: ChatStreaming {
    private let store: LocalModelStore
    private let cloud: any ChatStreaming

    init(store: LocalModelStore, cloud: any ChatStreaming) {
        self.store = store
        self.cloud = cloud
    }

    func streamReply(
        model: ModelOption,
        applicationKey: String,
        endUserKey: String?,
        history: [TranscriptEntry]
    ) -> AsyncThrowingStream<String, Error> {
        guard model.wireFormat == LocalModelStore.wireFormat else {
            return cloud.streamReply(
                model: model,
                applicationKey: applicationKey,
                endUserKey: endUserKey,
                history: history
            )
        }
        return store.streamReply(modelID: model.id, history: history)
    }
}
