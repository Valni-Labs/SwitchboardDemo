import Foundation
import Switchboard

final class SwitchboardChatService: ChatStreaming, Sendable {
    private let client: Client
    private let apiKey: String
    private let baseURL: URL
    private let endUserID: String?

    init(apiKey: String, baseURL: URL, endUserID: String?) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.endUserID = endUserID
        client = Client(apiKey: apiKey, baseURL: baseURL)
    }

    func streamReply(model: ModelOption, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error> {
        switch model.transport {
        case .openAICompatible:
            return streamViaChatCompletions(modelID: model.id, history: history)
        case .anthropicMessages:
            return streamViaAnthropicMessages(modelID: model.id, history: history)
        }
    }

    private func streamViaChatCompletions(modelID: String, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error> {
        let request = Chat.Request(
            model: Model(modelID),
            messages: history.map { entry in
                switch entry.role {
                case .user: .user(entry.text)
                case .assistant: .assistant(entry.text)
                }
            },
            user: endUserID
        )
        let client = client
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in client.streamChatCompletions(request) {
                        if let piece = chunk.choices.first?.delta.content, !piece.isEmpty {
                            continuation.yield(piece)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func streamViaAnthropicMessages(modelID: String, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error> {
        let adapter = AnthropicMessagesAdapter(
            modelID: modelID,
            apiKey: apiKey,
            endUserID: endUserID,
            baseURL: baseURL
        )
        let messages = history.map { entry -> ChatMessage in
            switch entry.role {
            case .user: ChatMessage(role: .user, text: entry.text)
            case .assistant: ChatMessage(role: .assistant, text: entry.text)
            }
        }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in adapter.generateRaw(messages: messages) {
                        if case .text(let piece) = chunk, !piece.isEmpty {
                            continuation.yield(piece)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
