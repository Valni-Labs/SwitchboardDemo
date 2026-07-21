import Switchboard

enum SwitchboardWireFormat {
    static let anthropicMessages = "anthropic-messages"
    static let openaiResponses = "openai-responses"
    static let openaiChat = "openai-chat"
}

enum NativeChatBody {
    static let maxTokens = 8192

    static func make(model: ModelOption, history: [TranscriptEntry], systemPrompt: String) -> RouterBody {
        switch model.wireFormat {
        case SwitchboardWireFormat.anthropicMessages:
            .anthropic(AnthropicMessagesRequest(
                model: model.id,
                messages: history.map { entry in
                    AnthropicMessage(role: entry.role.anthropicRole, content: .string(entry.text))
                },
                maxTokens: Double(maxTokens),
                system: .text(systemPrompt)
            ))
        case SwitchboardWireFormat.openaiResponses:
            .openaiPro(OpenAIResponsesRequest(
                model: model.id,
                input: .array(history.map(\.responsesItem)),
                instructions: systemPrompt,
                maxOutputTokens: Double(maxTokens)
            ))
        default:
            .openaiGeneric(openAIChatRequest(modelID: model.id, history: history, systemPrompt: systemPrompt))
        }
    }

    static func openAIChatRequest(modelID: String, history: [TranscriptEntry], systemPrompt: String) -> OpenAIChatRequest {
        OpenAIChatRequest(
            model: modelID,
            messages: [OpenAIChatMessage(role: .system, content: .string(systemPrompt))]
                + history.map { entry in
                    OpenAIChatMessage(role: entry.role.openAIChatRole, content: .string(entry.text))
                },
            maxTokens: Double(maxTokens)
        )
    }
}

extension TranscriptEntry.Role {
    var anthropicRole: AnthropicMessageRole {
        switch self {
        case .user: .user
        case .assistant: .assistant
        }
    }

    var openAIChatRole: OpenAIChatMessageRole {
        switch self {
        case .user: .user
        case .assistant: .assistant
        }
    }

    var responsesRole: String {
        switch self {
        case .user: "user"
        case .assistant: "assistant"
        }
    }

    var responsesContentPartType: String {
        switch self {
        case .user: "input_text"
        case .assistant: "output_text"
        }
    }
}

extension TranscriptEntry {
    var responsesItem: SwitchboardJSON {
        .object([
            "type": .string("message"),
            "role": .string(role.responsesRole),
            "content": .array([
                .object([
                    "type": .string(role.responsesContentPartType),
                    "text": .string(text),
                ]),
            ]),
        ])
    }
}
