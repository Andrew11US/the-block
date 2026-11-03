protocol VehicleRepository {
    func loadVehicles() async throws -> [Vehicle]
}
