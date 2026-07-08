import Foundation
import Testing
@testable import SwitchboardDemo

struct FakeModelCatalog: ModelCatalogProviding {
    let models: [ModelOption]

    func loadModels(applicationKey: String) async throws -> [ModelOption] {
        models
    }
}

@MainActor
final class KeyMutatingCatalog: ModelCatalogProviding {
    let models: [ModelOption]
    var onLoad: (() -> Void)?

    init(models: [ModelOption]) {
        self.models = models
    }

    func loadModels(applicationKey: String) async throws -> [ModelOption] {
        onLoad?()
        return models
    }
}

struct FakeChatStream: ChatStreaming {
    let pieces: [String]
    var error: Error? = nil

    func streamReply(
        model: ModelOption,
        applicationKey: String,
        endUserKey: String?,
        history: [TranscriptEntry]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for piece in pieces {
                continuation.yield(piece)
            }
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}

struct FakeStreamError: LocalizedError {
    var errorDescription: String? { "stream failed" }
}

struct FailingCatalog: ModelCatalogProviding {
    func loadModels(applicationKey: String) async throws -> [ModelOption] {
        throw FakeStreamError()
    }
}

@MainActor
enum LocalModelStoreFixture {
    static func makeStorageDirectory(availableRepositoryIDs: [String]) throws -> URL {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalModelStoreFixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        for repositoryID in availableRepositoryIDs {
            let directoryName = repositoryID.replacingOccurrences(of: "/", with: "_")
            let modelDirectory = storageDirectory.appendingPathComponent(directoryName)
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: modelDirectory.appendingPathComponent(".complete").path, contents: nil)
        }
        return storageDirectory
    }

    static func make(availableRepositoryIDs: [String] = [], userDefaults: UserDefaults? = nil) throws -> LocalModelStore {
        let storageDirectory = try makeStorageDirectory(availableRepositoryIDs: availableRepositoryIDs)
        let defaults = userDefaults ?? UserDefaults(suiteName: "LocalModelStoreFixture-\(UUID().uuidString)")!
        defaults.set(availableRepositoryIDs, forKey: "localModelRepositoryIDs")
        return LocalModelStore(userDefaults: defaults, storageDirectory: storageDirectory)
    }
}

@MainActor
struct ChatViewModelTests {
    private let options = [
        ModelOption(id: "anthropic/claude-sonnet-4-5", displayName: "Claude Sonnet 4.5", wireFormat: "anthropic-messages", contextWindow: 200_000),
        ModelOption(id: "openai/gpt-5", displayName: "GPT-5", wireFormat: "openai-compat", contextWindow: 400_000),
    ]

    private func makeViewModel(
        models: [ModelOption]? = nil,
        pieces: [String] = [],
        streamError: Error? = nil
    ) -> ChatViewModel {
        ChatViewModel(
            modelCatalog: FakeModelCatalog(models: models ?? options),
            chatService: FakeChatStream(pieces: pieces, error: streamError)
        )
    }

    private func makeHybridViewModel(cloud: any ModelCatalogProviding) throws -> ChatViewModel {
        let store = try LocalModelStoreFixture.make(availableRepositoryIDs: ["test-org/Fixture-Model-4bit"])
        return ChatViewModel(
            modelCatalog: HybridModelCatalog(store: store, cloud: cloud),
            chatService: FakeChatStream(pieces: []),
            localModelStore: store
        )
    }

    @Test func loadModelsWithEmptyKeyShowsOnDeviceModelsOnly() async throws {
        let viewModel = try makeHybridViewModel(cloud: FakeModelCatalog(models: options))
        await viewModel.loadModels()
        #expect(!viewModel.models.isEmpty)
        #expect(viewModel.models.allSatisfy { $0.wireFormat == LocalModelStore.wireFormat })
        #expect(viewModel.selectedModelID == viewModel.models.first?.id)
    }

    @Test func loadModelsWithKeyListsOnDeviceThenCloudModels() async throws {
        let viewModel = try makeHybridViewModel(cloud: FakeModelCatalog(models: options))
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        #expect(viewModel.models.first?.wireFormat == LocalModelStore.wireFormat)
        #expect(Array(viewModel.models.suffix(options.count)) == options)
    }

    @Test func cloudCatalogFailureKeepsOnDeviceModelsAndSurfacesError() async throws {
        let viewModel = try makeHybridViewModel(cloud: FailingCatalog())
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        #expect(viewModel.statusMessage == "stream failed")
        #expect(!viewModel.models.isEmpty)
        #expect(viewModel.models.allSatisfy { $0.wireFormat == LocalModelStore.wireFormat })
        #expect(viewModel.selectedModelID == viewModel.models.first?.id)
    }

    @Test func canSendAllowsOnDeviceModelWithoutApplicationKey() async throws {
        let viewModel = try makeHybridViewModel(cloud: FakeModelCatalog(models: options))
        await viewModel.loadModels()
        viewModel.draft = "Hello"
        #expect(viewModel.canSend)
    }

    @Test func loadModelsDropsResultsWhenKeyChangesDuringLoad() async {
        let catalog = KeyMutatingCatalog(models: options)
        let viewModel = ChatViewModel(
            modelCatalog: catalog,
            chatService: FakeChatStream(pieces: [])
        )
        viewModel.applicationKey = "swb_original"
        catalog.onLoad = { viewModel.applicationKey = "swb_changed" }
        await viewModel.loadModels()
        #expect(viewModel.models.isEmpty)
        #expect(viewModel.selectedModelID == nil)
    }

    @Test func loadModelsWithEmptyKeyDropsCloudModels() async throws {
        let viewModel = try makeHybridViewModel(cloud: FakeModelCatalog(models: options))
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        #expect(viewModel.models.count == 1 + options.count)
        viewModel.applicationKey = ""
        await viewModel.loadModels()
        #expect(viewModel.models.allSatisfy { $0.wireFormat == LocalModelStore.wireFormat })
    }

    @Test func loadModelsPopulatesAndSelectsFirst() async {
        let viewModel = makeViewModel()
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        #expect(viewModel.models == options)
        #expect(viewModel.selectedModelID == options[0].id)
        #expect(viewModel.statusMessage == nil)
    }

    @Test func sendAppendsUserEntryAndAccumulatesAssistantStream() async {
        let viewModel = makeViewModel(pieces: ["Hel", "lo"])
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        viewModel.draft = "Hi there"
        await viewModel.send()
        #expect(viewModel.transcript.count == 2)
        #expect(viewModel.transcript[0].role == .user)
        #expect(viewModel.transcript[0].text == "Hi there")
        #expect(viewModel.transcript[1].role == .assistant)
        #expect(viewModel.transcript[1].text == "Hello")
        #expect(viewModel.draft.isEmpty)
        #expect(viewModel.isStreaming == false)
    }

    @Test func streamFailureRemovesEmptyAssistantEntryAndSurfacesError() async {
        let viewModel = makeViewModel(streamError: FakeStreamError())
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        viewModel.draft = "Hi"
        await viewModel.send()
        #expect(viewModel.transcript.count == 1)
        #expect(viewModel.transcript[0].role == .user)
        #expect(viewModel.statusMessage == "stream failed")
    }

    @Test func emptyApplicationKeyBlocksSend() async {
        let viewModel = makeViewModel()
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        viewModel.applicationKey = "   "
        viewModel.draft = "Hi"
        #expect(viewModel.canSend == false)
        await viewModel.send()
        #expect(viewModel.transcript.isEmpty)
    }

    @Test func setupErrorSurfacesMessage() {
        let viewModel = ChatViewModel(setupError: "bad configuration")
        #expect(viewModel.statusMessage == "bad configuration")
        #expect(viewModel.canSend == false)
    }

    @Test func blankDraftCannotSend() async {
        let viewModel = makeViewModel()
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        viewModel.draft = "   "
        #expect(viewModel.canSend == false)
        await viewModel.send()
        #expect(viewModel.transcript.isEmpty)
    }
}

@MainActor
struct LocalModelStoreTests {
    @Test func parseAcceptsBareRepositoryID() {
        #expect(LocalModelStore.parseRepositoryID("mlx-community/Qwen2.5-3B-Instruct-4bit") == "mlx-community/Qwen2.5-3B-Instruct-4bit")
    }

    @Test func parseAcceptsHuggingFaceURL() {
        #expect(LocalModelStore.parseRepositoryID("https://huggingface.co/mlx-community/Llama-3.2-1B-Instruct-4bit") == "mlx-community/Llama-3.2-1B-Instruct-4bit")
        #expect(LocalModelStore.parseRepositoryID("huggingface.co/mlx-community/Llama-3.2-1B-Instruct-4bit/") == "mlx-community/Llama-3.2-1B-Instruct-4bit")
        #expect(LocalModelStore.parseRepositoryID("https://huggingface.co/mlx-community/Llama-3.2-1B-Instruct-4bit?library=mlx") == "mlx-community/Llama-3.2-1B-Instruct-4bit")
        #expect(LocalModelStore.parseRepositoryID("https://huggingface.co/mlx-community/Llama-3.2-1B-Instruct-4bit#model-card") == "mlx-community/Llama-3.2-1B-Instruct-4bit")
    }

    @Test func parseRejectsInvalidInput() {
        #expect(LocalModelStore.parseRepositoryID("not a repo") == nil)
        #expect(LocalModelStore.parseRepositoryID("justonecomponent") == nil)
        #expect(LocalModelStore.parseRepositoryID("too/many/components") == nil)
        #expect(LocalModelStore.parseRepositoryID("") == nil)
    }

    @Test func downloadedModelIsAvailableInPickerOptions() throws {
        let store = try LocalModelStoreFixture.make(availableRepositoryIDs: ["test-org/Fixture-Model-4bit"])
        #expect(store.pickerOptions.count == 1)
        #expect(store.pickerOptions.first?.wireFormat == LocalModelStore.wireFormat)
        #expect(store.pickerOptions.first?.id == "test-org/Fixture-Model-4bit")
    }

    @Test func addRejectsInvalidInputAndDeduplicates() throws {
        let store = try LocalModelStoreFixture.make(availableRepositoryIDs: ["test-org/Fixture-Model-4bit"])
        #expect(throws: LocalModelStore.InputError.self) {
            try store.add("nonsense")
        }
        let existing = try store.add("test-org/Fixture-Model-4bit")
        #expect(store.models.count == 1)
        #expect(existing.id == "test-org/Fixture-Model-4bit")
    }

    @Test func persistedModelsRestoreAcrossStoreInstances() throws {
        let defaults = UserDefaults(suiteName: "LocalModelStoreFixture-\(UUID().uuidString)")!
        let storageDirectory = try LocalModelStoreFixture.makeStorageDirectory(availableRepositoryIDs: ["test-org/Fixture-Model-4bit"])
        defaults.set(["test-org/Fixture-Model-4bit"], forKey: "localModelRepositoryIDs")
        let restored = LocalModelStore(userDefaults: defaults, storageDirectory: storageDirectory)
        #expect(restored.models.count == 1)
        #expect(restored.pickerOptions.first?.id == "test-org/Fixture-Model-4bit")
    }

    @Test func removeDeletesModelAndPersistence() throws {
        let defaults = UserDefaults(suiteName: "LocalModelStoreFixture-\(UUID().uuidString)")!
        let store = try LocalModelStoreFixture.make(availableRepositoryIDs: ["test-org/Fixture-Model-4bit"], userDefaults: defaults)
        let localModel = try #require(store.model(for: "test-org/Fixture-Model-4bit"))
        store.remove(localModel)
        #expect(store.models.isEmpty)
        #expect(store.pickerOptions.isEmpty)
        #expect(defaults.stringArray(forKey: "localModelRepositoryIDs") == [])
    }
}

struct DemoConfigurationTests {
    @Test func missingBaseURLUsesDefault() throws {
        let configuration = try DemoConfiguration.fromEnvironment([:])
        #expect(configuration.baseURL.scheme == "https")
    }

    @Test func customBaseURLPassesThrough() throws {
        let configuration = try DemoConfiguration.fromEnvironment([
            "SWITCHBOARD_BASE_URL": "https://switchboard.example.com",
        ])
        #expect(configuration.baseURL.absoluteString == "https://switchboard.example.com")
    }

    @Test func emptyBaseURLUsesDefault() throws {
        let configuration = try DemoConfiguration.fromEnvironment([
            "SWITCHBOARD_BASE_URL": "",
        ])
        #expect(configuration.baseURL.scheme == "https")
    }
}
