protocol ChatStreaming: Sendable {
    func streamReply(modelID: String, history: [TranscriptEntry]) -> AsyncThrowingStream<String, Error>
}
