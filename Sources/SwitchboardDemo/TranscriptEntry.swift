import Foundation

struct TranscriptEntry: Identifiable, Hashable, Sendable {
    enum Role: Hashable, Sendable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var text: String
}
