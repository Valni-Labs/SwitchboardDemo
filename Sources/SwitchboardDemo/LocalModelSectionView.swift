import SwiftUI
import SwitchboardLocal

struct LocalModelSectionView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var repositoryInput = ""

    var body: some View {
        if let store = viewModel.localModelStore {
            VStack(alignment: .leading, spacing: 6) {
                Text("Local models")
                    .font(.caption.bold())
                HStack(spacing: 8) {
                    TextField("huggingface.co/organization/model", text: $repositoryInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                        .onSubmit(load)
                    Button("Load", action: load)
                        .disabled(LocalModelStore.parseRepositoryID(repositoryInput) == nil)
                }
                HStack(spacing: 6) {
                    ForEach(LocalModelStore.suggestions) { suggestion in
                        Button("\(suggestion.displayName) · \(suggestion.approximateSize)") {
                            viewModel.addLocalModel(suggestion.repositoryID)
                        }
                        .font(.caption)
                        .disabled(store.model(for: suggestion.repositoryID) != nil)
                    }
                }
                ForEach(store.models) { localModel in
                    LocalModelRowView(localModel: localModel) {
                        viewModel.removeLocalModel(localModel)
                    }
                }
            }
        }
    }

    private func load() {
        guard LocalModelStore.parseRepositoryID(repositoryInput) != nil else { return }
        viewModel.addLocalModel(repositoryInput)
        repositoryInput = ""
    }
}

struct LocalModelRowView: View {
    @ObservedObject var localModel: LocalModel
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(localModel.displayName)
                .font(.caption)
                .lineLimit(1)
            stateLabel
            Spacer(minLength: 0)
            if case .downloading = localModel.state {
                Button("Cancel") { localModel.cancelDownload() }
                    .font(.caption)
            } else {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch localModel.state {
        case .notDownloaded:
            Text("Not downloaded").font(.caption).foregroundStyle(.secondary)
        case .downloading(let progress, _, _):
            ProgressView(value: progress)
                .frame(width: 120)
            Text("\(Int(progress * 100))%").font(.caption).foregroundStyle(.secondary)
        case .downloaded:
            Text("Ready").font(.caption).foregroundStyle(.secondary)
        case .loading:
            Text("Loading…").font(.caption).foregroundStyle(.secondary)
        case .ready:
            Text("Ready").font(.caption).foregroundStyle(.green)
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.red).lineLimit(1)
            Button("Retry") { localModel.download() }.font(.caption)
        }
    }
}
