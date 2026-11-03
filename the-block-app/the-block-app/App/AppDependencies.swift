import Foundation

struct AppDependencies {
    let loadInventory: LoadInventory
    let bidRepository: any BidRepository
    let watchlistRepository: any WatchlistRepository

    init(bundle: Bundle = .main, bidSource: (any LocalBidDataSource)? = nil) {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let watchlistDefaults = testing
            ? UserDefaults(suiteName: "com.Andrew11US.the-block-app.ui-testing.watchlist")! : .standard
        watchlistRepository = LocalWatchlistRepository(defaults: watchlistDefaults)
        if testing && ProcessInfo.processInfo.arguments.contains("--reset-watchlist") {
            watchlistRepository.vehicleIDs = []
        }
        let fileName = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            ? "ui-testing-demo-bids-v1.json" : "demo-bids-v1.json"
        bidRepository = LocalBidRepository(source: bidSource ?? FileBidDataSource(
            url: URL.applicationSupportDirectory.appending(path: "TheBlock/\(fileName)")
        ))
        loadInventory = LoadInventory(repository: BundledVehicleRepository(
            source: BundledVehicleDataSource(bundle: bundle)
        ))
    }

    func makeInventoryViewModel() -> InventoryViewModel {
        InventoryViewModel(loadInventory: loadInventory, bidRepository: bidRepository,
                           watchlistRepository: watchlistRepository)
    }
}
