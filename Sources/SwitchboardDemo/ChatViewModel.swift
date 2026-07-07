import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    private let modelCatalog: ModelCatalogProviding?
    private let injectedChatService: ChatStreaming?
    private let baseURL: URL

    var applicationKey = ""
    var endUserKey = ""
    var models: [ModelOption] = []
    var selectedModelID: String?
    var transcript: [TranscriptEntry] = []
    var draft = ""
    var isStreaming = false
    var statusMessage: String?

    init(modelCatalog: ModelCatalogProviding, baseURL: URL) {
        self.modelCatalog = modelCatalog
        self.injectedChatService = nil
        self.baseURL = baseURL
    }

    init(modelCatalog: ModelCatalogProviding, chatService: ChatStreaming?) {
        self.modelCatalog = modelCatalog
        self.injectedChatService = chatService
        self.baseURL = URL(string: "https://switchboard.valni.app")!
    }

    init(setupError: String) {
        modelCatalog = nil
        injectedChatService = nil
        baseURL = URL(string: "https://switchboard.valni.app")!
        statusMessage = setupError
    }

    var canSend: Bool {
        let hasCredential = injectedChatService != nil
            || !applicationKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasCredential
            && !isStreaming
            && selectedModelID != nil
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadModels() async {
        guard let modelCatalog else { return }
        do {
            models = try await modelCatalog.loadModels()
            if selectedModelID == nil {
                selectedModelID = models.first?.id
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func send() async {
        guard canSend, let selectedModelID else { return }

        let service: ChatStreaming
        if let injected = injectedChatService {
            service = injected
        } else {
            let trimmedKey = applicationKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty else { return }
            let trimmedEndUserKey = endUserKey.trimmingCharacters(in: .whitespacesAndNewlines)
            service = SwitchboardChatService(
                apiKey: trimmedKey,
                baseURL: baseURL,
                endUserID: trimmedEndUserKey.isEmpty ? nil : trimmedEndUserKey
            )
        }

        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        statusMessage = nil
        transcript.append(TranscriptEntry(role: .user, text: text))
        let history = transcript
        transcript.append(TranscriptEntry(role: .assistant, text: ""))
        isStreaming = true
        defer { isStreaming = false }
        do {
            for try await piece in service.streamReply(modelID: selectedModelID, history: history) {
                transcript[transcript.count - 1].text += piece
            }
        } catch {
            if let lastEntry = transcript.last, lastEntry.role == .assistant, lastEntry.text.isEmpty {
                transcript.removeLast()
            }
            statusMessage = error.localizedDescription
        }
    }
}
