import Foundation
import Switchboard

struct TranscriptEntry: Identifiable, Hashable, Sendable {
    enum Role: Hashable, Sendable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var text: String
}

extension TranscriptEntry.Role {
    var chatMessageRole: ChatMessage.Role {
        switch self {
        case .user: .user
        case .assistant: .assistant
        }
    }
}
