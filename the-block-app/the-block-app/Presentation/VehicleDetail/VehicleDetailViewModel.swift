import Observation

@MainActor
@Observable
final class VehicleDetailViewModel {
    let vehicle: Vehicle
    private(set) var bidState: BidState
    private let repository: any BidRepository

    init(vehicle: Vehicle, repository: any BidRepository) {
        self.vehicle = vehicle
        self.repository = repository
        bidState = repository.state(for: vehicle)
    }

    var userBid: Int? {
        _ = bidState
        guard let saved = repository.states[vehicle.id], BidState.resolve(vehicle, override: saved) == saved else { return nil }
        return saved.currentBid
    }

    func observeBids() async {
        for await _ in repository.updates() {
            guard !Task.isCancelled else { break }
            bidState = repository.state(for: vehicle)
        }
    }

    func makeBidViewModel() -> BidViewModel {
        BidViewModel(vehicle: vehicle, repository: repository)
    }
}
