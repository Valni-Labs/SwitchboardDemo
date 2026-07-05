protocol ModelCatalogProviding: Sendable {
    func loadModels() async throws -> [ModelOption]
}
