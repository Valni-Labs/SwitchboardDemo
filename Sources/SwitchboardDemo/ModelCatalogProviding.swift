protocol ModelCatalogProviding: Sendable {
    func loadModels(applicationKey: String) async throws -> [ModelOption]
}
