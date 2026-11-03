import Foundation
import Testing
@testable import the_block_app

@MainActor
struct InventorySearchTests {
    private func inventory() async throws -> [Vehicle] {
        try await AppDependencies().loadInventory()
    }

    @Test func blankSearchKeepsOriginalOrder() async throws {
        let vehicles = try await inventory()
        #expect(SearchVehicles()(vehicles, query: " \n\t ") == vehicles)
    }

    @Test func mixedCaseAndWordsAcrossFieldsMatch() async throws {
        let vehicles = try await inventory()
        let matches = SearchVehicles()(vehicles, query: "  mAzDa\t2025\nCX-5  ")
        #expect(!matches.isEmpty)
        #expect(matches.contains { $0.lot == "A-0001" })
        #expect(matches.allSatisfy { $0.make == "Mazda" && $0.year == 2025 && $0.model == "CX-5" })
        #expect(SearchVehicles()(vehicles, query: "2025 Mazda nonexistent").isEmpty)
    }

    @Test func vinAndLotIdentifyExactVehicle() async throws {
        let vehicles = try await inventory()
        let first = try #require(vehicles.first)
        #expect(SearchVehicles()(vehicles, query: first.vin.lowercased()) == [first])
        #expect(SearchVehicles()(vehicles, query: first.lot.lowercased()) == [first])
    }

    @Test func modelSearchAndNoResults() async throws {
        let vehicles = try await inventory()
        let matches = SearchVehicles()(vehicles, query: "Golf GTI")
        #expect(!matches.isEmpty)
        #expect(matches.allSatisfy { $0.model == "Golf GTI" })
        #expect(SearchVehicles()(vehicles, query: "unlisted-vehicle").isEmpty)
    }

    @Test func clearingSearchRestoresInventory() async throws {
        let model = InventoryViewModel(loadInventory: AppDependencies().loadInventory, bidRepository: EmptyBidRepository())
        await model.load()
        model.query = "CG2UAF4T8LRBBVWJY"
        #expect(model.results.count == 1)
        #expect(model.results.first?.lot == "A-0001")
        model.query = "no-matching-vehicle"
        #expect(model.results.isEmpty)
        model.query = ""
        #expect(model.results == model.vehicles)
        #expect(model.results.count == 200)
    }

    @Test func filtersCombineWithSearchAndPreserveOrder() async throws {
        let vehicles = try await inventory()
        let first = try #require(vehicles.first)
        let filters = VehicleFilters(make: first.make, bodyStyle: first.bodyStyle,
                                     fuelType: first.fuelType, titleStatus: first.titleStatus,
                                     province: first.province, minimumYear: first.year,
                                     maximumOdometerKm: first.odometerKm)
        #expect(filters.activeCount == 7)
        #expect(SearchVehicles()(vehicles, query: first.vin, filters: filters) == [first])
        let expected = vehicles.filter {
            $0.make == first.make && $0.bodyStyle == first.bodyStyle
                && $0.fuelType == first.fuelType && $0.titleStatus == first.titleStatus
                && $0.province == first.province && $0.year >= first.year
                && $0.odometerKm <= first.odometerKm
        }
        #expect(SearchVehicles()(vehicles, query: "", filters: filters) == expected)
        #expect(SearchVehicles()(vehicles, query: first.vin,
                                 filters: VehicleFilters(minimumYear: first.year + 1)).isEmpty)
        #expect(SearchVehicles()(vehicles, query: first.vin,
                                 filters: VehicleFilters(maximumOdometerKm: first.odometerKm - 1)).isEmpty)
    }

    @Test func resettingFiltersRetainsQuery() async throws {
        let model = InventoryViewModel(loadInventory: AppDependencies().loadInventory, bidRepository: EmptyBidRepository())
        await model.load()
        model.query = "Mazda"
        let searchResults = model.results
        model.filters = VehicleFilters(make: "BMW")
        #expect(model.results.isEmpty)
        model.filters = VehicleFilters()
        #expect(model.results == searchResults)
        #expect(model.filters.activeCount == 0)
    }
}
