import Foundation
import Testing
@testable import SwitchboardDemo

struct FakeModelCatalog: ModelCatalogProviding {
    let models: [ModelOption]

    func loadModels() async throws -> [ModelOption] {
        models
    }
}

struct FakeChatStream: ChatStreaming {
    let pieces: [String]
    var error: Error? = nil

    func streamReply(modelID: String, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error> {
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

@MainActor
struct ChatViewModelTests {
    private let options = [
        ModelOption(id: "anthropic/claude-sonnet-4-5", displayName: "Claude Sonnet 4.5"),
        ModelOption(id: "openai/gpt-5", displayName: "GPT-5"),
    ]

    @Test func loadModelsPopulatesAndSelectsFirst() async {
        let viewModel = ChatViewModel(
            modelCatalog: FakeModelCatalog(models: options),
            chatService: FakeChatStream(pieces: [])
        )
        await viewModel.loadModels()
        #expect(viewModel.models == options)
        #expect(viewModel.selectedModelID == options[0].id)
    }

    @Test func sendAppendsUserEntryAndAccumulatesAssistantStream() async {
        let viewModel = ChatViewModel(
            modelCatalog: FakeModelCatalog(models: options),
            chatService: FakeChatStream(pieces: ["Hel", "lo"])
        )
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
        let viewModel = ChatViewModel(
            modelCatalog: FakeModelCatalog(models: options),
            chatService: FakeChatStream(pieces: [], error: FakeStreamError())
        )
        await viewModel.loadModels()
        viewModel.draft = "Hi"
        await viewModel.send()
        #expect(viewModel.transcript.count == 1)
        #expect(viewModel.transcript[0].role == .user)
        #expect(viewModel.statusMessage == "stream failed")
    }

    @Test func missingChatServiceSurfacesStatusAndBlocksSend() {
        let viewModel = ChatViewModel(
            modelCatalog: FakeModelCatalog(models: options),
            chatService: nil
        )
        viewModel.draft = "Hi"
        #expect(viewModel.statusMessage != nil)
        #expect(viewModel.canSend == false)
    }

    @Test func setupErrorSurfacesMessage() {
        let viewModel = ChatViewModel(setupError: "bad configuration")
        #expect(viewModel.statusMessage == "bad configuration")
        #expect(viewModel.canSend == false)
    }

    @Test func blankDraftCannotSend() async {
        let viewModel = ChatViewModel(
            modelCatalog: FakeModelCatalog(models: options),
            chatService: FakeChatStream(pieces: [])
        )
        await viewModel.loadModels()
        viewModel.draft = "   "
        #expect(viewModel.canSend == false)
        await viewModel.send()
        #expect(viewModel.transcript.isEmpty)
    }
}

struct DemoConfigurationTests {
    @Test func missingKeyIsNil() throws {
        let configuration = try DemoConfiguration.fromEnvironment([:])
        #expect(configuration.apiKey == nil)
        #expect(configuration.endUserID == nil)
    }

    @Test func emptyValuesNormalizeToNil() throws {
        let configuration = try DemoConfiguration.fromEnvironment([
            "SWITCHBOARD_API_KEY": "",
            "SWITCHBOARD_END_USER_ID": "",
        ])
        #expect(configuration.apiKey == nil)
        #expect(configuration.endUserID == nil)
    }

    @Test func valuesPassThrough() throws {
        let configuration = try DemoConfiguration.fromEnvironment([
            "SWITCHBOARD_API_KEY": "swb_test",
            "SWITCHBOARD_BASE_URL": "https://switchboard-dev.valni.app",
            "SWITCHBOARD_END_USER_ID": "demo-user",
        ])
        #expect(configuration.apiKey == "swb_test")
        #expect(configuration.baseURL.absoluteString == "https://switchboard-dev.valni.app")
        #expect(configuration.endUserID == "demo-user")
    }
}
