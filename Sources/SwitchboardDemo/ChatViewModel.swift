import Foundation
import Observation
import SwitchboardLocal

@Observable
@MainActor
final class ChatViewModel {
    private let modelCatalog: ModelCatalogProviding?
    private let chatService: ChatStreaming?
    let localModelStore: LocalModelStore?

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

    init(modelCatalog: ModelCatalogProviding, chatService: ChatStreaming, localModelStore: LocalModelStore? = nil) {
        self.modelCatalog = modelCatalog
        self.chatService = chatService
        self.localModelStore = localModelStore
        localModelStore?.onAvailabilityChange = { [weak self] newlyAvailableID in
            Task { await self?.handleLocalAvailabilityChange(newlyAvailableID) }
        }
    }

    init(setupError: String) {
        modelCatalog = nil
        chatService = nil
        localModelStore = nil
        statusMessage = setupError
    }

    func addLocalModel(_ input: String) {
        guard let localModelStore else { return }
        do {
            try localModelStore.add(input)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func removeLocalModel(_ localModel: LocalModel) {
        localModelStore?.remove(localModel)
    }

    private func handleLocalAvailabilityChange(_ newlyAvailableID: String?) async {
        await loadModels()
        if let newlyAvailableID, models.contains(where: { $0.id == newlyAvailableID }) {
            selectedModelID = newlyAvailableID
        }
    }

    private var trimmedApplicationKey: String {
        applicationKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var selectedModel: ModelOption? {
        models.first { $0.id == selectedModelID }
    }

    var canSend: Bool {
        chatService != nil
            && (isSelectedModelOnDevice || !trimmedApplicationKey.isEmpty)
            && !isStreaming
            && selectedModel != nil
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isSelectedModelOnDevice: Bool {
        selectedModel?.wireFormat == LocalModelStore.wireFormat
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
        isLoadingModels = true
        defer { isLoadingModels = false }
        do {
            let loaded = try await modelCatalog.loadModels(applicationKey: key)
            guard key == trimmedApplicationKey else { return }
            models = loaded
            if selectedModelID == nil || !loaded.contains(where: { $0.id == selectedModelID }) {
                selectedModelID = loaded.first?.id
            }
            statusMessage = nil
        } catch {
            guard key == trimmedApplicationKey else { return }
            statusMessage = error.localizedDescription
            let keylessModels = (try? await modelCatalog.loadModels(applicationKey: "")) ?? []
            guard key == trimmedApplicationKey else { return }
            models = keylessModels
            if selectedModelID == nil || !keylessModels.contains(where: { $0.id == selectedModelID }) {
                selectedModelID = keylessModels.first?.id
            }
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
