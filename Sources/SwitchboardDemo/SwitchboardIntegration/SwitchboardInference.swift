import Foundation
import Switchboard
import SwitchboardNative

final class SwitchboardInference: ChatStreaming, Sendable {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
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
                    guard let endUserKey, !endUserKey.isEmpty else {
                        throw ProviderError.missingEndUserID
                    }
                    let provider = try InferenceProvider(
                        apiKey: applicationKey,
                        endUserID: endUserKey,
                        baseURL: baseURL,
                        contextWindow: model.contextWindow
                    )
                    let body = NativeChatBody.make(
                        model: model,
                        history: history,
                        systemPrompt: ChatDefaults.systemPrompt
                    )
                    for try await chunk in provider.generate(body) {
                        switch chunk {
                        case .text(let piece):
                            if !piece.isEmpty { continuation.yield(piece) }
                        case .paywall(let event):
                            continuation.finish(throwing: PaywallError(event: event))
                            return
                        case .reasoning, .toolCall:
                            break
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
