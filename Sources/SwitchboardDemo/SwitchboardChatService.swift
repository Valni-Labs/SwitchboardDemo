import Foundation
import Switchboard

final class SwitchboardChatService: ChatStreaming, Sendable {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    enum ServiceError: LocalizedError {
        case unsupportedWireFormat(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedWireFormat(let wireFormat):
                "This demo only speaks \(WireFormat.openAICompatible) and \(WireFormat.anthropicMessages), but the selected model uses '\(wireFormat)'."
            }
        }
    }

    struct PaywallError: LocalizedError {
        let event: PaywallEvent

        var errorDescription: String? {
            switch event {
            case .outOfTokens(let tier, _, _, _):
                "Out of credits on the \(tier.wireValue) tier. Top the account up in the portal to continue."
            }
        }
    }

    func streamReply(
        model: ModelOption,
        applicationKey: String,
        endUserKey: String?,
        history: [TranscriptEntry]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let provider = try makeProvider(
                        model: model,
                        applicationKey: applicationKey,
                        endUserKey: endUserKey
                    )
                    let messages = history.map { entry in
                        ChatMessage(role: entry.role.chatMessageRole, text: entry.text)
                    }
                    for try await chunk in provider.generateRaw(messages: messages) {
                        switch chunk {
                        case .text(let piece):
                            if !piece.isEmpty { continuation.yield(piece) }
                        case .paywall(let event):
                            continuation.finish(throwing: PaywallError(event: event))
                            return
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

    private func makeProvider(
        model: ModelOption,
        applicationKey: String,
        endUserKey: String?
    ) throws -> RawGenerationProvider {
        switch model.wireFormat {
        case WireFormat.anthropicMessages:
            return AnthropicMessagesAdapter(
                modelID: model.id,
                apiKey: applicationKey,
                endUserID: endUserKey,
                baseURL: baseURL,
                contextWindow: model.contextWindow
            )
        case WireFormat.openAICompatible:
            return SwitchboardProvider(
                modelID: model.id,
                apiKey: applicationKey,
                endUserID: endUserKey,
                baseURL: baseURL,
                contextWindow: model.contextWindow
            )
        default:
            throw ServiceError.unsupportedWireFormat(model.wireFormat)
        }
    }
}

private extension TranscriptEntry.Role {
    var chatMessageRole: ChatMessage.Role {
        switch self {
        case .user: .user
        case .assistant: .assistant
        }
    }
}
