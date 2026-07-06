enum ModelTransport: Sendable, Hashable {
    case openAICompatible
    case anthropicMessages

    static func from(wireFormat: String?) -> ModelTransport {
        wireFormat == WireFormat.anthropicMessages ? .anthropicMessages : .openAICompatible
    }
}

enum WireFormat {
    static let anthropicMessages = "anthropic-messages"
}

struct ModelOption: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    var transport: ModelTransport = .openAICompatible
}
