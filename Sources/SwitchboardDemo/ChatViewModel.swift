import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    private let modelCatalog: ModelCatalogProviding?
    private let chatService: ChatStreaming?

    var applicationKey = ""
    var endUserKey = ""
    var models: [ModelOption] = []
    var selectedModelID: String?
    var transcript: [TranscriptEntry] = []
    var draft = ""
    var isStreaming = false
    var isLoadingModels = false
    var statusMessage: String?

    private var modelLoadTask: Task<Void, Never>?

    init(modelCatalog: ModelCatalogProviding, chatService: ChatStreaming) {
        self.modelCatalog = modelCatalog
        self.chatService = chatService
    }

    init(setupError: String) {
        modelCatalog = nil
        chatService = nil
        statusMessage = setupError
    }

    private var trimmedApplicationKey: String {
        applicationKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var selectedModel: ModelOption? {
        models.first { $0.id == selectedModelID }
    }

    var canSend: Bool {
        chatService != nil
            && !trimmedApplicationKey.isEmpty
            && !isStreaming
            && selectedModel != nil
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func reloadModelsAfterKeyChange() {
        modelLoadTask?.cancel()
        modelLoadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }
            await self?.loadModels()
        }
    }

    func loadModels() async {
        guard let modelCatalog else { return }
        let key = trimmedApplicationKey
        guard !key.isEmpty else {
            models = []
            selectedModelID = nil
            statusMessage = nil
            return
        }
        isLoadingModels = true
        defer { isLoadingModels = false }
        do {
            let loaded = try await modelCatalog.loadModels(applicationKey: key)
            models = loaded
            if selectedModelID == nil || !loaded.contains(where: { $0.id == selectedModelID }) {
                selectedModelID = loaded.first?.id
            }
            statusMessage = nil
        } catch {
            models = []
            selectedModelID = nil
            statusMessage = error.localizedDescription
        }
    }

    func send() async {
        guard canSend, let chatService, let model = selectedModel else { return }
        let trimmedEndUserKey = endUserKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        statusMessage = nil
        transcript.append(TranscriptEntry(role: .user, text: text))
        let history = transcript
        transcript.append(TranscriptEntry(role: .assistant, text: ""))
        isStreaming = true
        defer { isStreaming = false }
        do {
            let stream = chatService.streamReply(
                model: model,
                applicationKey: trimmedApplicationKey,
                endUserKey: trimmedEndUserKey.isEmpty ? nil : trimmedEndUserKey,
                history: history
            )
            for try await piece in stream {
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
