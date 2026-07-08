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

    @Test func loadModelsWithEmptyKeyShowsOnDeviceModelsOnly() async {
        let viewModel = ChatViewModel(
            modelCatalog: HybridModelCatalog(cloud: FakeModelCatalog(models: options)),
            chatService: FakeChatStream(pieces: [])
        )
        await viewModel.loadModels()
        #expect(!viewModel.models.isEmpty)
        #expect(viewModel.models.allSatisfy { $0.wireFormat == LocalModelSupport.wireFormat })
        #expect(viewModel.selectedModelID == viewModel.models.first?.id)
    }

    @Test func loadModelsWithKeyListsOnDeviceThenCloudModels() async {
        let viewModel = ChatViewModel(
            modelCatalog: HybridModelCatalog(cloud: FakeModelCatalog(models: options)),
            chatService: FakeChatStream(pieces: [])
        )
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        let onDeviceCount = LocalModelSupport.models.count
        #expect(viewModel.models.prefix(onDeviceCount).allSatisfy { $0.wireFormat == LocalModelSupport.wireFormat })
        #expect(Array(viewModel.models.suffix(options.count)) == options)
    }

    @Test func cloudCatalogFailureKeepsOnDeviceModelsAndSurfacesError() async {
        let viewModel = ChatViewModel(
            modelCatalog: HybridModelCatalog(cloud: FailingCatalog()),
            chatService: FakeChatStream(pieces: [])
        )
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        #expect(viewModel.statusMessage == "stream failed")
        #expect(!viewModel.models.isEmpty)
        #expect(viewModel.models.allSatisfy { $0.wireFormat == LocalModelSupport.wireFormat })
        #expect(viewModel.selectedModelID == viewModel.models.first?.id)
    }

    @Test func canSendAllowsOnDeviceModelWithoutApplicationKey() async {
        let viewModel = ChatViewModel(
            modelCatalog: HybridModelCatalog(cloud: FakeModelCatalog(models: options)),
            chatService: FakeChatStream(pieces: [])
        )
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

    @Test func loadModelsWithEmptyKeyDropsCloudModels() async {
        let viewModel = ChatViewModel(
            modelCatalog: HybridModelCatalog(cloud: FakeModelCatalog(models: options)),
            chatService: FakeChatStream(pieces: [])
        )
        viewModel.applicationKey = "swb_test"
        await viewModel.loadModels()
        #expect(viewModel.models.count == LocalModelSupport.models.count + options.count)
        viewModel.applicationKey = ""
        await viewModel.loadModels()
        #expect(viewModel.models.allSatisfy { $0.wireFormat == LocalModelSupport.wireFormat })
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
