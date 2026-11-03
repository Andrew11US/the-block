struct LoadInventory {
    let repository: any VehicleRepository

    func callAsFunction() async throws -> [Vehicle] {
        try await repository.loadVehicles()
    }
}
