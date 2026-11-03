import Foundation

struct BundledVehicleRepository: VehicleRepository {
    let source: BundledVehicleDataSource

    func loadVehicles() async throws -> [Vehicle] {
        try Self.decode(await source.read())
    }

    static func decode(_ data: Data) throws -> [Vehicle] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([VehicleDTO].self, from: data).map { $0.toDomain() }
    }
}
