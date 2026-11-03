import SwiftUI

struct VehicleDetailView: View {
    @State var viewModel: VehicleDetailViewModel
    var isSaved = false
    var toggleWatchlist: (() -> Void)?
    @State private var showingBidSheet = false
    private var vehicle: Vehicle { viewModel.vehicle }

    // A fresh Date.now in body would reschedule the timeline during layout.
    @State private var timelineOrigin = Date.now

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                TimelineView(.explicit(AuctionSchedule(vehicle: vehicle)?.timelineDates(from: timelineOrigin) ?? [timelineOrigin])) { context in
                    AuctionStatusFooter(vehicle: vehicle, now: context.date, showsTopDivider: false, showsSeconds: true)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                VehiclePhotoGallery(images: vehicle.images)
                    .id(vehicle.id)
                    .vehicleDetailSurface()
                identityCard
                auctionCard
                VehicleSpecificationsSection(vehicle: vehicle)
                VehicleConditionSection(vehicle: vehicle)
                DealershipSection(vehicle: vehicle)
            }
            .padding(16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(InventoryPalette.navy)
        .background(InventoryPalette.background.ignoresSafeArea())
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bidDock
        }
        .sheet(isPresented: $showingBidSheet) {
            BidSheet(viewModel: viewModel.makeBidViewModel())
        }
        .task { await viewModel.observeBids() }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: VehicleDisplayFormatter.identity(vehicle))
                        .font(.system(size: 24, weight: .semibold))
                        .tracking(-0.65)
                        .accessibilityIdentifier("vehicleIdentity")
                    Text("\(vehicle.trim) · \(vehicle.engine) · \(vehicle.drivetrain)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let toggleWatchlist {
                    VehicleWatchlistButton(vehicle: vehicle, isSaved: isSaved, toggle: toggleWatchlist)
                        .background(InventoryPalette.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(InventoryPalette.navy.opacity(0.12), lineWidth: 1)
                        }
                }
            }
            HStack(spacing: 6) {
                Text("LOT \(vehicle.lot)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(InventoryPalette.lotNavy, in: RoundedRectangle(cornerRadius: 6))
                TitleStatusBadge(status: vehicle.titleStatus)
            }
            Text("VIN · \(vehicle.vin)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("vehicleVIN")
            Label("\(vehicle.city), \(vehicle.province)", systemImage: "mappin.and.ellipse")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .vehicleDetailSurface()
    }

    private var auctionCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VehicleDetailCardHeading(title: "Auction", icon: "hammer")
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.bidState.currentBid == nil ? "STARTING BID" : "CURRENT BID")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.3)
                            .foregroundStyle(.secondary)
                        money(viewModel.bidState.currentBid ?? vehicle.startingBid, size: 31)
                            .accessibilityIdentifier("currentBid")
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.bidState.bidCount) bids")
                            .font(.system(size: 14, weight: .semibold))
                            .accessibilityIdentifier("bidCount")
                        Text(reserveLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                if let amount = viewModel.userBid {
                    Text("Your latest bid · \(VehicleDisplayFormatter.money(amount))")
                        .font(.subheadline.weight(.semibold))
                }
                if let minimum = BidPolicy().minimum(for: vehicle, state: viewModel.bidState) {
                    Text("Minimum next bid: \(VehicleDisplayFormatter.money(minimum))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No further demo bids available")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            if let schedule = AuctionSchedule(vehicle: vehicle) {
                HStack {
                    Label("Auction ends", systemImage: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(scheduleEnd(schedule.end))
                        .fontWeight(.semibold)
                }
                .font(.system(size: 11))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(InventoryPalette.mist)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .vehicleDetailSurface()
    }

    private var reserveLabel: String {
        switch BidPolicy().reserve(for: vehicle, state: viewModel.bidState) {
        case .noReserve: String(localized: "No reserve")
        case .notMet: String(localized: "Reserve not met")
        case .met: String(localized: "Reserve met")
        }
    }

    private func scheduleEnd(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: vehicle.auctionTimezone)
        formatter.dateFormat = "MMM d · HH:mm z"
        return formatter.string(from: date)
    }

    private func money(_ amount: Int, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(amount.formatted(.currency(code: "CAD").presentation(.narrow).precision(.fractionLength(0))))
                .font(.system(size: size, weight: .semibold))
                .tracking(-1)
                .monospacedDigit()
            Text("CAD")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var bidDock: some View {
        TimelineView(.explicit(AuctionSchedule(vehicle: vehicle)?.timelineDates(from: timelineOrigin) ?? [timelineOrigin])) { context in
            let status = AuctionSchedule(vehicle: vehicle)?.status(at: context.date)
            let minimum = BidPolicy().minimum(for: vehicle, state: viewModel.bidState)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MINIMUM NEXT BID")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        if let minimum {
                            money(minimum, size: 23)
                        } else {
                            Text("Limit reached").font(.system(size: 14))
                        }
                    }
                    Spacer(minLength: 0)
                    Button { showingBidSheet = true } label: {
                        HStack(spacing: 8) {
                            Text(status == .live ? (viewModel.userBid == nil ? "Place bid" : "Raise bid") : status == .upcoming ? "Not started" : status == .ended ? "Auction ended" : "Unavailable")
                            if status == .live { Image(systemName: "arrow.up.right") }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(InventoryPalette.navy.opacity(status == .live && minimum != nil ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 11))
                        .foregroundStyle(InventoryPalette.card)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("placeBid")
                    .disabled(status != .live || minimum == nil)
                }
                Text("Simulated bidding · CAD 100 minimum increment after the first bid")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .foregroundStyle(InventoryPalette.navy)
            .background(InventoryPalette.card)
            .overlay(alignment: .top) { Divider() }
        }
    }
}
