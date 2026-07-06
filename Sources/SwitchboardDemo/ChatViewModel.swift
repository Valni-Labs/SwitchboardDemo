import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    private let modelCatalog: ModelCatalogProviding?
    private let chatService: ChatStreaming?

    var models: [ModelOption] = []
    var selectedModelID: String?
    var transcript: [TranscriptEntry] = []
    var draft = ""
    var isStreaming = false
    var statusMessage: String?

    init(modelCatalog: ModelCatalogProviding, chatService: ChatStreaming?) {
        self.modelCatalog = modelCatalog
        self.chatService = chatService
        if chatService == nil {
            statusMessage = "SWITCHBOARD_API_KEY is not set. Relaunch with SWITCHBOARD_API_KEY=swb_... to chat."
        }
    }

    init(setupError: String) {
        modelCatalog = nil
        chatService = nil
        statusMessage = setupError
    }

    var canSend: Bool {
        chatService != nil
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
        guard canSend, let chatService, let selectedModelID,
              let model = models.first(where: { $0.id == selectedModelID }) else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        statusMessage = nil
        transcript.append(TranscriptEntry(role: .user, text: text))
        let history = transcript
        transcript.append(TranscriptEntry(role: .assistant, text: ""))
        isStreaming = true
        defer { isStreaming = false }
        do {
            for try await piece in chatService.streamReply(model: model, history: history) {
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
