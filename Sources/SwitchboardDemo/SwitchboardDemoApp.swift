import AppKit
import SwiftUI

@main
struct SwitchboardDemoApp: App {
    @State private var viewModel = SwitchboardDemoApp.makeViewModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup("Switchboard Demo") {
            ChatView(viewModel: viewModel)
        }
    }

    @MainActor
    private static func makeViewModel() -> ChatViewModel {
        do {
            let configuration = try DemoConfiguration.fromEnvironment()
            let localModelStore = LocalModelStore()
            let modelCatalog = HybridModelCatalog(store: localModelStore, cloud: SwitchboardModelCatalog(baseURL: configuration.baseURL))
            let chatService = HybridChatService(store: localModelStore, cloud: SwitchboardChatService(baseURL: configuration.baseURL))
            return ChatViewModel(modelCatalog: modelCatalog, chatService: chatService, localModelStore: localModelStore)
        } catch {
            return ChatViewModel(setupError: error.localizedDescription)
        }
    }
}
