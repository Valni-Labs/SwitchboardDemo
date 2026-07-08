import Foundation
import Switchboard

final class SwitchboardModelCatalog: ModelCatalogProviding, Sendable {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func loadModels(applicationKey: String) async throws -> [ModelOption] {
        let client = Client(apiKey: applicationKey, baseURL: baseURL)
        let pickerModels = try await client.models()
        return pickerModels
            .map { pickerModel in
                ModelOption(
                    id: pickerModel.id,
                    displayName: pickerModel.displayName,
                    wireFormat: pickerModel.wireFormat,
                    contextWindow: pickerModel.contextWindow
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
