import Foundation
import Linecard

final class LinecardModelCatalog: ModelCatalogProviding, Sendable {
    private let client: LinecardClient

    init() throws {
        client = try LinecardClient()
    }

    func loadModels() async throws -> [ModelOption] {
        let outcome = try await client.refresh()
        let catalog = switch outcome {
        case .unchanged(let catalog), .updated(let catalog):
            catalog
        }
        let wireFormatByProvider = Dictionary(
            catalog.providers.map { ($0.id, $0.wireFormat) },
            uniquingKeysWith: { first, _ in first }
        )
        return catalog.models
            .map { model in
                ModelOption(
                    id: model.id,
                    displayName: model.displayName,
                    transport: .from(wireFormat: wireFormatByProvider[model.provider] ?? nil)
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
