import Foundation

struct BundledVehicleDataSource {
    enum LoadError: Error { case missingResource }
    let bundle: Bundle

    func read() async throws -> Data {
        guard let url = bundle.url(forResource: "vehicles", withExtension: "json") else {
            throw LoadError.missingResource
        }
        return try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: url)
        }.value
    }
}
