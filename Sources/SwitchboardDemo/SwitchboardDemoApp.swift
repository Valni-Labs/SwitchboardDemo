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
            let modelCatalog = try LinecardModelCatalog()
            return ChatViewModel(modelCatalog: modelCatalog, baseURL: configuration.baseURL)
        } catch {
            return ChatViewModel(setupError: error.localizedDescription)
        }
    }
}
