import Foundation
import Testing
@testable import the_block_app

@MainActor
struct WatchlistTests {
    @Test func savesRestoresAndRemovesVehiclesIndependentlyOfSearch() async throws {
        let suite = "WatchlistTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = LocalWatchlistRepository(defaults: defaults)
        let inventory = AppDependencies().loadInventory
        let model = InventoryViewModel(loadInventory: inventory, bidRepository: EmptyBidRepository(),
                                       watchlistRepository: repository)
        await model.load()
        let first = try #require(model.vehicles.first)
        let second = try #require(model.vehicles.last)
        #expect(model.watchlistedVehicles.isEmpty)
        model.toggleWatchlist(second)
        model.toggleWatchlist(first)
        model.query = "no-matching-vehicle"
        model.filters = VehicleFilters(make: "unlisted-make")
        #expect(model.results.isEmpty)
        #expect(model.watchlistedVehicles == [first, second])

        let restored = InventoryViewModel(loadInventory: inventory, bidRepository: EmptyBidRepository(),
                                          watchlistRepository: LocalWatchlistRepository(defaults: defaults))
        await restored.load()
        #expect(restored.watchlistedVehicles == [first, second])
        restored.toggleWatchlist(first)
        #expect(restored.watchlistedVehicles == [second])
        restored.toggleWatchlist(second)
        #expect(restored.watchlistedVehicles.isEmpty)
        #expect(repository.vehicleIDs.isEmpty)
    }
}
