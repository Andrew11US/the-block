import Foundation
import Observation

@MainActor
@Observable
final class InventoryViewModel {
    enum State {
        case loading
        case loaded([Vehicle])
        case failed
    }

    private(set) var state: State = .loading
    var query = ""
    var filters = VehicleFilters()
    private(set) var watchlistedIDs: Set<Vehicle.ID>
    private let watchlistRepository: any WatchlistRepository
    private let searchVehicles = SearchVehicles()

    var vehicles: [Vehicle] {
        guard case .loaded(let vehicles) = state else { return [] }
        return vehicles
    }

    var results: [Vehicle] {
        searchVehicles(vehicles, query: query, filters: filters)
    }

    private let loadInventory: LoadInventory
    private let bidRepository: any BidRepository
    private var bidStates: [String: BidState]
    private(set) var restorationWarning: Bool
    var resetError: String?

    init(loadInventory: LoadInventory, bidRepository: any BidRepository,
         watchlistRepository: (any WatchlistRepository)? = nil) {
        self.loadInventory = loadInventory
        self.bidRepository = bidRepository
        let watchlistRepository = watchlistRepository ?? LocalWatchlistRepository()
        self.watchlistRepository = watchlistRepository
        watchlistedIDs = watchlistRepository.vehicleIDs
        bidStates = bidRepository.states
        restorationWarning = bidRepository.restorationFailed
    }

    func userBid(for vehicle: Vehicle) -> Int? {
        guard let saved = bidStates[vehicle.id], BidState.resolve(vehicle, override: saved) == saved else { return nil }
        return saved.currentBid
    }

    var watchlistedVehicles: [Vehicle] {
        vehicles.filter { watchlistedIDs.contains($0.id) }
    }

    func toggleWatchlist(_ vehicle: Vehicle) {
        if watchlistedIDs.contains(vehicle.id) {
            watchlistedIDs.remove(vehicle.id)
        } else {
            watchlistedIDs.insert(vehicle.id)
        }
        watchlistRepository.vehicleIDs = watchlistedIDs
    }

    func bidState(for vehicle: Vehicle) -> BidState {
        BidState.resolve(vehicle, override: bidStates[vehicle.id])
    }

    func observeBids() async {
        for await states in bidRepository.updates() {
            guard !Task.isCancelled else { break }
            bidStates = states
            restorationWarning = bidRepository.restorationFailed
        }
    }

    func makeDetailViewModel(for vehicle: Vehicle) -> VehicleDetailViewModel {
        VehicleDetailViewModel(vehicle: vehicle, repository: bidRepository)
    }

    func resetBids() {
        do {
            try ResetDemoBids(repository: bidRepository)()
            bidStates = bidRepository.states
            restorationWarning = false
            resetError = nil
        } catch {
            resetError = String(localized: "Demo bids could not be reset. Nothing changed. Please try again.")
        }
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await loadInventory())
        } catch {
            state = .failed
        }
    }
}
