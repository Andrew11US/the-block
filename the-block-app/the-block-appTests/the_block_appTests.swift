import Foundation
import Testing
@testable import the_block_app

@MainActor
struct InventoryFoundationTests {
    @Test func bundledInventoryPreservesFixture() async throws {
        let bundle = Bundle(for: BundleMarker.self)
        // Resources belong to the host app, not the test bundle.
        let appBundle = Bundle.main
        #expect(bundle != appBundle)
        let vehicles = try await AppDependencies(bundle: appBundle).loadInventory()
        #expect(vehicles.count == 200)
        #expect(Set(vehicles.map(\.id)).count == 200)
        #expect(vehicles.filter { $0.currentBid == nil }.count == 112)
        #expect(vehicles.filter { $0.reservePrice == nil }.count == 60)
        #expect(vehicles.filter { $0.buyNowPrice == nil }.count == 161)
        let first = try #require(vehicles.first)
        #expect(first.id == "4e3cd74f-bb88-4efe-b234-bcb2f7474b40")
        #expect(first.odometerKm == 24534)
        #expect(first.conditionGrade == 4)
        #expect(first.damageNotes.isEmpty)
        #expect(first.images.count == 4)
        #expect(first.sellingDealership == "Highway 7 Auto Sales")
        #expect(first.auctionStart == "2026-11-02T18:00:00")
        #expect(vehicles.filter { $0.titleStatus == "salvage" }.count == 14)
    }

    @Test func malformedInventoryThrows() {
        #expect(throws: (any Error).self) {
            try BundledVehicleRepository.decode(Data("[{\"id\":\"incomplete\"}]".utf8))
        }
    }

    @Test func missingResourceThrows() async {
        await #expect(throws: BundledVehicleDataSource.LoadError.self) {
            try await BundledVehicleDataSource(bundle: Bundle(for: BundleMarker.self)).read()
        }
    }

    @Test func successfulLoadShowsInventory() async {
        let model = InventoryViewModel(loadInventory: LoadInventory(repository: StubRepository(fails: false)), bidRepository: EmptyBidRepository())
        if case .loading = model.state {} else { Issue.record("Expected initial loading state") }
        await model.load()
        if case .loaded(let vehicles) = model.state {
            #expect(vehicles.isEmpty)
        } else { Issue.record("Expected loaded state") }
    }

    @Test func failedLoadCanRetry() async {
        let repository = RecoveringRepository()
        let model = InventoryViewModel(loadInventory: LoadInventory(repository: repository), bidRepository: EmptyBidRepository())
        await model.load()
        if case .failed = model.state {} else { Issue.record("Expected failed state") }
        await model.load()
        if case .loaded = model.state {} else { Issue.record("Expected retry to recover") }
    }
}

private final class BundleMarker: NSObject {}

private struct StubRepository: VehicleRepository {
    let fails: Bool
    func loadVehicles() async throws -> [Vehicle] {
        if fails { throw TestError.unavailable }
        return []
    }
}

private final class RecoveringRepository: VehicleRepository {
    private var attempts = 0
    func loadVehicles() async throws -> [Vehicle] {
        attempts += 1
        if attempts == 1 { throw TestError.unavailable }
        return []
    }
}

private enum TestError: Error { case unavailable }
