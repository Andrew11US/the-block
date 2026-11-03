import Foundation

final class LocalWatchlistRepository: WatchlistRepository {
    private let defaults: UserDefaults
    private let key = "watchlistedVehicleIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var vehicleIDs: Set<Vehicle.ID> {
        get { Set(defaults.stringArray(forKey: key) ?? []) }
        set { defaults.set(newValue.sorted(), forKey: key) }
    }
}
