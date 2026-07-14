import Foundation
import Combine
import Switchboard
import SwitchboardLocal

@MainActor
@Observable
final class LocalModelStore {
    nonisolated static let wireFormat = "on-device"

    struct Suggestion: Identifiable {
        let displayName: String
        let repositoryID: String
        let approximateSize: String

        var id: String { repositoryID }
    }

    static let suggestions = [
        Suggestion(displayName: "Llama 3.2 1B", repositoryID: "mlx-community/Llama-3.2-1B-Instruct-4bit", approximateSize: "0.7 GB"),
        Suggestion(displayName: "Qwen 2.5 3B", repositoryID: "mlx-community/Qwen2.5-3B-Instruct-4bit", approximateSize: "1.9 GB"),
    ]

    enum InputError: LocalizedError {
        case invalidRepositoryID(String)

        var errorDescription: String? {
            switch self {
            case .invalidRepositoryID(let input):
                "'\(input)' is not a Hugging Face repository. Use the form organization/model or paste the model page URL."
            }
        }
    }

    enum StreamError: LocalizedError {
        case unknownModel(String)
        case notReady(String)

        var errorDescription: String? {
            switch self {
            case .unknownModel(let id):
                "No local model loaded for '\(id)'."
            case .notReady(let message):
                "The local model could not be prepared: \(message)"
            }
        }
    }

    private(set) var models: [LocalModel] = []
    var onAvailabilityChange: ((String?) -> Void)?

    private let userDefaults: UserDefaults
    private let storageDirectory: URL
    private var stateObservations: [String: AnyCancellable] = [:]
    private var availableIDs: Set<String> = []

    private static let persistenceKey = "localModelRepositoryIDs"

    init(
        userDefaults: UserDefaults = .standard,
        storageDirectory: URL = LocalModel.defaultStorageDirectory
    ) {
        self.userDefaults = userDefaults
        self.storageDirectory = storageDirectory
        for repositoryID in userDefaults.stringArray(forKey: Self.persistenceKey) ?? [] {
            insert(repositoryID: repositoryID, startDownload: false)
        }
        availableIDs = Set(models.filter { Self.isAvailable($0.state) }.map(\.id))
    }

    var pickerOptions: [ModelOption] {
        models
            .filter { Self.isAvailable($0.state) }
            .map { localModel in
                ModelOption(
                    id: localModel.id,
                    displayName: "\(localModel.displayName) (on this Mac)",
                    wireFormat: Self.wireFormat,
                    contextWindow: ModelLimits.localDefault.contextWindow
                )
            }
    }

    func model(for id: String) -> LocalModel? {
        models.first { $0.id == id }
    }

    @discardableResult
    func add(_ input: String) throws -> LocalModel {
        guard let repositoryID = Self.parseRepositoryID(input) else {
            throw InputError.invalidRepositoryID(input)
        }
        if let existing = model(for: repositoryID) {
            switch existing.state {
            case .notDownloaded, .failed: existing.download()
            case .downloaded, .downloading, .loading, .ready: break
            }
            return existing
        }
        let created = insert(repositoryID: repositoryID, startDownload: true)
        persist()
        return created
    }

    func remove(_ localModel: LocalModel) {
        localModel.delete()
        models.removeAll { $0.id == localModel.id }
        stateObservations.removeValue(forKey: localModel.id)
        if availableIDs.contains(localModel.id) {
            availableIDs.remove(localModel.id)
            onAvailabilityChange?(nil)
        }
        persist()
    }

    static func parseRepositoryID(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://", "http://"] where text.lowercased().hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
        }
        if text.lowercased().hasPrefix("huggingface.co/") {
            text = String(text.dropFirst("huggingface.co/".count))
        }
        if let suffixStart = text.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            text = String(text[..<suffixStart])
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = text.split(separator: "/")
        guard components.count == 2, !text.contains(" ") else { return nil }
        return text
    }

    nonisolated func streamReply(modelID: String, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                guard let localModel = self.model(for: modelID) else {
                    continuation.finish(throwing: StreamError.unknownModel(modelID))
                    return
                }
                do {
                    try await Self.ensureReady(localModel)
                    let messages = [ChatMessage(role: .system, text: ChatDefaults.systemPrompt)]
                        + history.map { entry in
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
                    self.model(for: modelID)?.provider.abort()
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
                throw StreamError.notReady(message)
            case .notDownloaded, .downloaded, .downloading, .loading:
                try await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private static func isAvailable(_ state: LocalModel.State) -> Bool {
        switch state {
        case .downloaded, .loading, .ready: true
        case .notDownloaded, .downloading, .failed: false
        }
    }

    @discardableResult
    private func insert(repositoryID: String, startDownload: Bool) -> LocalModel {
        let displayName = repositoryID.split(separator: "/").last.map(String.init) ?? repositoryID
        let localModel = LocalModel(
            huggingFaceRepoID: repositoryID,
            displayName: displayName,
            storageDirectory: storageDirectory
        )
        models.append(localModel)
        observe(localModel)
        if startDownload, case .notDownloaded = localModel.state {
            localModel.download()
        }
        return localModel
    }

    private func observe(_ localModel: LocalModel) {
        stateObservations[localModel.id] = localModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self, weak localModel] in
                guard let self, let localModel else { return }
                let available = Self.isAvailable(localModel.state)
                if available, !self.availableIDs.contains(localModel.id) {
                    self.availableIDs.insert(localModel.id)
                    self.onAvailabilityChange?(localModel.id)
                } else if !available, self.availableIDs.contains(localModel.id) {
                    self.availableIDs.remove(localModel.id)
                    self.onAvailabilityChange?(nil)
                }
            }
    }

    private func persist() {
        userDefaults.set(models.map(\.id), forKey: Self.persistenceKey)
    }
}
