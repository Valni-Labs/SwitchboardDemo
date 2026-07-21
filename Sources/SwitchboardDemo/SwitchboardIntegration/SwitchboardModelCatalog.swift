import Foundation
import Switchboard

final class SwitchboardModelCatalog: ModelCatalogProviding, Sendable {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func loadModels(applicationKey: String) async throws -> [ModelOption] {
        let client = Client(apiKey: applicationKey, baseURL: baseURL)
        let page = try await client.models()
        return page.models
            .compactMap { record in
                Self.wireFormatTag(for: record.kind).map { tag in
                    ModelOption(
                        id: record.id,
                        displayName: record.id,
                        wireFormat: tag,
                        contextWindow: nil
                    )
                }
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func wireFormatTag(for kind: ProfileByKind) -> String? {
        switch kind {
        case .anthropic: SwitchboardWireFormat.anthropicMessages
        case .openaiPro: SwitchboardWireFormat.openaiResponses
        case .openaiGeneric: SwitchboardWireFormat.openaiChat
        case .google, .unrecognized: nil
        }
    }
}
