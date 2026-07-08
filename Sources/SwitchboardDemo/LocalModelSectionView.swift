import SwiftUI
import SwitchboardLocal

struct LocalModelSectionView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var repositoryInput = ""
    @State private var isLocalInfoPresented = false

    var body: some View {
        if let store = viewModel.localModelStore {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Local models")
                        .font(.title3.bold())
                    Button {
                        isLocalInfoPresented.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isLocalInfoPresented, arrowEdge: .bottom) {
                        Text("Local models run entirely on this Mac. No key, and no network once downloaded.\n\nModels must be in MLX format. The mlx-community organization on Hugging Face publishes ready-converted checkpoints, and 4-bit quantized builds are the right default. Enter a repository as organization/model or paste its page URL, then press Load to download once; after that the model loads from disk and appears in the model picker.\n\nThe model must fit in free memory: a 1B model wants roughly 1 GB, a 7B closer to 4 GB. Requires Apple Silicon.")
                            .font(.callout)
                            .frame(width: 360, alignment: .leading)
                            .padding()
                    }
                }
                Text("Add local model")
                    .font(.caption.bold())
                HStack(spacing: 8) {
                    TextField("huggingface.co/organization/model", text: $repositoryInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                        .onSubmit(load)
                    Button("Load", action: load)
                        .disabled(LocalModelStore.parseRepositoryID(repositoryInput) == nil)
                }
                Menu("Suggested local models") {
                    ForEach(LocalModelStore.suggestions) { suggestion in
                        Button("\(suggestion.displayName) · \(suggestion.approximateSize)") {
                            repositoryInput = suggestion.repositoryID
                        }
                        .disabled(store.model(for: suggestion.repositoryID) != nil)
                    }
                }
                .font(.caption)
                .fixedSize()
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
            Button("Download") { localModel.download() }.font(.caption)
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
