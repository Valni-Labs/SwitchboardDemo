import SwiftUI

struct TranscriptEntryView: View {
    let entry: TranscriptEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(roleLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(entry.text.isEmpty ? "…" : entry.text)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var roleLabel: String {
        switch entry.role {
        case .user: "You"
        case .assistant: "Assistant"
        }
    }
}
