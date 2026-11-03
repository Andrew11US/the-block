import SwiftUI

struct WatchlistView: View {
    let viewModel: InventoryViewModel
    var showsBids = false
    @State private var showsEnded = false

    private var vehicles: [Vehicle] {
        guard showsBids else { return viewModel.watchlistedVehicles }
        return viewModel.vehicles.filter { vehicle in
            viewModel.userBid(for: vehicle) != nil &&
            ((AuctionSchedule(vehicle: vehicle)?.status(at: .now) == .ended) == showsEnded)
        }
    }
    @Environment(\.dismiss) private var dismiss
    @State private var vehicleForBid: Vehicle?

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty && !showsBids {
                    emptyState
                } else {
                    List {
                        if showsBids {
                            Picker("Auctions", selection: $showsEnded) {
                                Text("Active").tag(false)
                                Text("Ended").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        if vehicles.isEmpty {
                            emptyState
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        ForEach(vehicles) { vehicle in
                            CoastalVehicleInventoryRow(
                                vehicle: vehicle,
                                bidState: viewModel.bidState(for: vehicle),
                                isSaved: viewModel.watchlistedIDs.contains(vehicle.id),
                                toggleWatchlist: { viewModel.toggleWatchlist(vehicle) },
                                reviewBid: { vehicleForBid = vehicle },
                                navigationAccessibilityIdentifier: "savedVehicle-\(vehicle.lot)",
                                userBid: viewModel.userBid(for: vehicle)
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .accessibilityIdentifier("watchlistVehicles")
                }
            }
            .scrollContentBackground(.hidden)
            .background(InventoryPalette.background.ignoresSafeArea())
            .navigationTitle(showsBids ? "My bids" : "Watchlist")
            .navigationDestination(for: Vehicle.ID.self) { id in
                if let vehicle = viewModel.vehicles.first(where: { $0.id == id }) {
                    VehicleDetailView(
                        viewModel: viewModel.makeDetailViewModel(for: vehicle),
                        isSaved: viewModel.watchlistedIDs.contains(vehicle.id),
                        toggleWatchlist: { viewModel.toggleWatchlist(vehicle) }
                    )
                }
            }
            .sheet(item: $vehicleForBid) { vehicle in
                BidSheet(viewModel: viewModel.makeDetailViewModel(for: vehicle).makeBidViewModel())
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("closeWatchlist")
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        ContentUnavailableView(showsBids ? "No bids here yet" : "Your watchlist is empty",
                               systemImage: showsBids ? "hammer" : "heart",
                               description: Text(showsBids ? "Vehicles you bid on appear here." : "Tap the heart beside a vehicle to save it here."))
    }
}
