import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var isConfigurationExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isConfigurationExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Configure Switchboard")
                            .font(.headline)
                        Image(systemName: isConfigurationExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, isConfigurationExpanded ? 0 : 10)

            if isConfigurationExpanded {
                configurationPanels
            }

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

            HStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Model picker")
                            .font(.caption.bold())
                        if viewModel.models.isEmpty {
                            Picker("Model", selection: $viewModel.selectedModelID) {
                                Text("Configure needed").tag(String?.none)
                            }
                            .labelsHidden()
                            .fixedSize()
                            .disabled(true)
                        } else {
                            Picker("Model", selection: $viewModel.selectedModelID) {
                                ForEach(viewModel.models) { option in
                                    Text(option.displayName).tag(Optional(option.id))
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                        Text("Enter keys or download a model.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                    if viewModel.isLoadingModels {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding()

                Divider()

                TextField("Message", text: $viewModel.draft)
                    .textFieldStyle(.plain)
                    .onSubmit(submit)
                    .padding()

                Button("Send", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canSend)
                    .padding(.trailing)
            }
            .frame(height: Self.inputBarHeight)
        }
        .frame(minWidth: 820, minHeight: 480)
        .task { await viewModel.loadModels() }
    }

    private static let inputBarHeight: CGFloat = 84

    private var configurationPanels: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cloud models")
                        .font(.title3.bold())
                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Application Key")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            SecureField("Your company key", text: $viewModel.applicationKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                                .onSubmit { Task { await viewModel.loadModels() } }
                                .onChange(of: viewModel.applicationKey) {
                                    viewModel.reloadModelsAfterKeyChange()
                                }
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
                .padding(8)
                .frame(width: 432, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            GroupBox {
                LocalModelSectionView(viewModel: viewModel)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
    }

    private func submit() {
        guard viewModel.canSend else { return }
        Task { await viewModel.send() }
    }
}
