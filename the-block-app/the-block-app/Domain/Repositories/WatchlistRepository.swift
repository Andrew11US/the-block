protocol WatchlistRepository: AnyObject {
    var vehicleIDs: Set<Vehicle.ID> { get set }
}
