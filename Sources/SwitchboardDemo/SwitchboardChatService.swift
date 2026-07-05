import Foundation
import Switchboard

final class SwitchboardChatService: ChatStreaming, Sendable {
    private let client: Client
    private let endUserID: String?

    init(apiKey: String, baseURL: URL, endUserID: String?) {
        client = Client(apiKey: apiKey, baseURL: baseURL)
        self.endUserID = endUserID
    }

    func streamReply(modelID: String, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error> {
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
}
