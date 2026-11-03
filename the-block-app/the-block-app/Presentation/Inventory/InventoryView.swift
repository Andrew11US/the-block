import SwiftUI

struct InventoryView: View {
    @State var viewModel: InventoryViewModel
    @State private var selectedVehicleID: Vehicle.ID?
    @State private var showingResetConfirmation = false
    @State private var showingFilters = false
    @State private var showingWatchlist = false
    @State private var showingMyBids = false
    @State private var vehicleForBid: Vehicle?
    @State private var auctionFilter: AuctionStatus?
    @State private var auctionDate = Date.now

    var body: some View {
        NavigationSplitView {
            inventory
            .scrollContentBackground(.hidden)
            .background(InventoryPalette.background.ignoresSafeArea())
            .navigationTitle("The Block")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.query, placement: .toolbar, prompt: "Search vehicles")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Watchlist", systemImage: viewModel.watchlistedVehicles.isEmpty ? "heart" : "heart.fill") {
                        showingWatchlist = true
                    }
                    .accessibilityIdentifier("showWatchlist")
                    .accessibilityValue("\(viewModel.watchlistedVehicles.count) saved vehicles")
                    Button("My bids", systemImage: "hammer") { showingMyBids = true }
                    Button("Reset demo bids", systemImage: "arrow.counterclockwise") {
                        showingResetConfirmation = true
                    }
                    .accessibilityIdentifier("resetDemoBids")
                }
                ToolbarItem(placement: .bottomBar) {
                    filterButton
                }
                ToolbarSpacer(.fixed, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            }
            .alert("Reset all demo bids?", isPresented: $showingResetConfirmation) {
                Button("Reset demo bids", role: .destructive) { viewModel.resetBids() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This restores the supplied inventory prices and bid counts on this device.")
            }
            .sheet(isPresented: $showingFilters) {
                InventoryFilterSheet(vehicles: viewModel.vehicles, filters: viewModel.filters) {
                    viewModel.filters = $0
                }
            }
            .sheet(isPresented: $showingMyBids) {
                WatchlistView(viewModel: viewModel, showsBids: true)
            }
            .sheet(isPresented: $showingWatchlist) {
                WatchlistView(viewModel: viewModel)
            }
            .sheet(item: $vehicleForBid) { vehicle in
                BidSheet(viewModel: viewModel.makeDetailViewModel(for: vehicle).makeBidViewModel())
            }
        } detail: {
            if let vehicle = viewModel.vehicles.first(where: { $0.id == selectedVehicleID }) {
                VehicleDetailView(
                    viewModel: viewModel.makeDetailViewModel(for: vehicle),
                    isSaved: viewModel.watchlistedIDs.contains(vehicle.id),
                    toggleWatchlist: { viewModel.toggleWatchlist(vehicle) }
                ).id(vehicle.id)
            } else {
                ContentUnavailableView("Select a vehicle", systemImage: "car.side",
                                       description: Text("Browse inventory to inspect a vehicle."))
            }
        }
        .task {
            await viewModel.load()
            await viewModel.observeBids()
        }
    }

    private var filterButton: some View {
        Button {
            showingFilters = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                if viewModel.filters.activeCount > 0 {
                    Text(viewModel.filters.activeCount.formatted())
                        .font(.caption.bold())
                }
            }
        }
        .tint(.primary)
        .accessibilityLabel("Filters")
        .accessibilityValue("\(viewModel.filters.activeCount) active")
        .accessibilityIdentifier("searchFilters")
        .disabled(viewModel.vehicles.isEmpty)
    }

    private func auctionFilterButton(_ title: String, status: AuctionStatus) -> some View {
        let selected = auctionFilter == status
        return Button {
            auctionFilter = selected ? nil : status
        } label: {
            Text(title)
                .font(.caption.weight(selected ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(InventoryPalette.navy.opacity(selected ? 1 : 0.65))
                .background(InventoryPalette.navy.opacity(selected ? 0.10 : 0.04),
                            in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("auctionFilter-\(title.lowercased())")
    }

    @ViewBuilder
    private var inventory: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading inventory…")
        case .loaded:
            let candidates = viewModel.results
            let results = candidates.filter { vehicle in
                auctionFilter == nil || vehicle.auctionSchedule?.status(at: auctionDate) == auctionFilter
            }
            List(selection: $selectedVehicleID) {
                if viewModel.restorationWarning {
                    Text("Saved demo bids could not be restored. Showing the supplied inventory. Reset demo bids to start again.")
                }
                if let message = viewModel.resetError {
                    Label(message, systemImage: "exclamationmark.circle")
                }
                Section {
                    ForEach(results) { vehicle in
                        CoastalVehicleInventoryRow(
                            vehicle: vehicle,
                            bidState: viewModel.bidState(for: vehicle),
                            isSaved: viewModel.watchlistedIDs.contains(vehicle.id),
                            toggleWatchlist: { viewModel.toggleWatchlist(vehicle) },
                            reviewBid: { vehicleForBid = vehicle },
                            userBid: viewModel.userBid(for: vehicle)
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    if results.isEmpty {
                        VStack(spacing: 12) {
                            Label("No vehicles found", systemImage: "magnifyingglass")
                                .font(.headline)
                            Text("Try another search or adjust your filters.")
                                .foregroundStyle(.secondary)
                            Button("Clear search") { viewModel.query = "" }
                                .accessibilityIdentifier("clearSearch")
                            if viewModel.filters.activeCount > 0 || auctionFilter != nil {
                                Button("Reset filters") {
                                    viewModel.filters = VehicleFilters()
                                    auctionFilter = nil
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                } header: {
                    HStack(spacing: 6) {
                        HStack(spacing: 6) {
                            auctionFilterButton("Live", status: .live)
                            auctionFilterButton("Upcoming", status: .upcoming)
                            auctionFilterButton("Ended", status: .ended)
                        }
                        Spacer(minLength: 4)
                        Text("\(results.count) of \(viewModel.vehicles.count) vehicles")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("resultCount")
                    }
                    .textCase(nil)
                    .padding(.leading, -12)
                    .padding(.bottom, 4)
                } footer: {
                    Text("Prototype inventory · CAD prices · Placeholder images")
                }
            }
            .listStyle(.insetGrouped)
            .task(id: viewModel.vehicles) {
                await observeAuctionTransitions()
            }
        case .failed:
            ContentUnavailableView {
                Label("Inventory unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text("The bundled inventory could not be loaded. Please try again.")
            } actions: {
                Button("Try again") { Task { await viewModel.load() } }
            }
        }
    }

    /// Keep List updates outside TimelineView's rendering/layout cycle.
    private func observeAuctionTransitions() async {
        auctionDate = .now
        let transitions = Set(viewModel.vehicles.compactMap(\.auctionSchedule)
            .flatMap(\.transitionDates)).sorted()
        for date in transitions {
            let delay = date.timeIntervalSinceNow
            guard delay > 0 else { continue }
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            auctionDate = .now
        }
    }

}
