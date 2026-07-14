protocol ChatStreaming: Sendable {
    func streamReply(
        model: ModelOption,
        applicationKey: String,
        endUserKey: String?,
        history: [TranscriptEntry]
    ) -> AsyncThrowingStream<String, Error>
}

enum ChatDefaults {
    static let systemPrompt = "You are a helpful assistant. Respond in English unless the user writes in another language."
}
