protocol ChatStreaming: Sendable {
    func streamReply(model: ModelOption, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error>
}
