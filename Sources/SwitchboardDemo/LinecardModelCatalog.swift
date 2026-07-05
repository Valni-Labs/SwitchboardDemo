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
        return catalog.models
            .map { ModelOption(id: $0.id, displayName: $0.displayName) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
