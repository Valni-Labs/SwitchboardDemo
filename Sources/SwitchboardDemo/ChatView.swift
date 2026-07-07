import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Picker("Model", selection: $viewModel.selectedModelID) {
                    ForEach(viewModel.models) { option in
                        Text(option.displayName).tag(Optional(option.id))
                    }
                }
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity, alignment: .leading)
                if viewModel.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Application Key")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            SecureField("Your company key", text: $viewModel.applicationKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                                .onSubmit { Task { await viewModel.loadModels() } }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("End User Key")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            TextField("User of your app key", text: $viewModel.endUserKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        }
                    }
                    Text("For demo only — see [platform.valni.ai](https://platform.valni.ai) for key management best practices.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Mint keys at valni.ai in platform/account.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.transcript) { entry in
                            TranscriptEntryView(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.transcript.last?.text) {
                    if let lastEntryID = viewModel.transcript.last?.id {
                        proxy.scrollTo(lastEntryID, anchor: .bottom)
                    }
                }
            }

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.08))
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Message", text: $viewModel.draft)
                    .textFieldStyle(.plain)
                    .onSubmit(submit)
                Button("Send", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canSend)
            }
            .padding()
        }
        .frame(minWidth: 620, minHeight: 480)
        .task { await viewModel.loadModels() }
    }

    private func submit() {
        guard viewModel.canSend else { return }
        Task { await viewModel.send() }
    }
}
