import SwiftUI

struct BidSheet: View {
    @State var viewModel: BidViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    private var vehicle: Vehicle { viewModel.vehicle }
    private var minimum: Int? { BidPolicy().minimum(for: vehicle, state: viewModel.bidState) }

    // A fresh Date.now in body would reschedule the timeline during layout.
    @State private var timelineOrigin = Date.now

    var body: some View {
        NavigationStack {
            TimelineView(.explicit(AuctionSchedule(vehicle: vehicle)?.timelineDates(from: timelineOrigin) ?? [timelineOrigin])) { context in
                let isLive = AuctionSchedule(vehicle: vehicle)?.status(at: context.date) == .live
                ScrollView {
                    VStack(spacing: 12) {
                        switch viewModel.stage {
                        case .editing:
                            countdown(at: context.date)
                            vehicleCard
                            amountCard(isLive: isLive)
                            auctionCard
                            simulationNotice
                        case .confirming(let amount):
                            countdown(at: context.date)
                            vehicleCard
                            reviewCard(amount)
                            simulationNotice
                        case .success(let state):
                            successCard(state)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(InventoryPalette.background.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    actions(isLive: isLive)
                }
            }
            .foregroundStyle(InventoryPalette.navy)
            .navigationTitle("Place demo bid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func countdown(at now: Date) -> some View {
        AuctionStatusFooter(vehicle: vehicle, now: now, showsTopDivider: false)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var vehicleCard: some View {
        HStack(spacing: 10) {
            VehicleImage(url: vehicle.images.first, priority: .detail)
                .frame(width: 62, height: 62)
                .background(InventoryPalette.mist)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: VehicleDisplayFormatter.identity(vehicle))
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.4)
                Text("\(vehicle.trim) · \(vehicle.engine) · \(vehicle.drivetrain)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text("LOT \(vehicle.lot)")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(InventoryPalette.lotNavy, in: RoundedRectangle(cornerRadius: 6))
                    TitleStatusBadge(status: vehicle.titleStatus)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .vehicleDetailSurface()
    }

    private func amountCard(isLive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your bid in CAD")
                .font(.system(size: 14, weight: .semibold))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("$")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Whole-dollar amount", text: $viewModel.amount)
                    .font(.system(size: 43, weight: .semibold))
                    .tracking(-1)
                    .keyboardType(.numberPad)
                    .focused($amountFocused)
                    .accessibilityIdentifier("bidAmount")
                    .disabled(!isLive || minimum == nil)
                Text("CAD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 7) {
                ForEach([100, 500, 1_000], id: \.self) { increment in
                    Button {
                        increaseAmount(by: increment)
                    } label: {
                        Text("+ \(shortMoney(increment))")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(InventoryPalette.mist, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(InventoryPalette.navy.opacity(0.10), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isLive || incrementedAmount(by: increment) == nil)
                    .accessibilityIdentifier("bidIncrement-\(increment)")
                }
            }
            if let minimum {
                Label("Minimum \(shortMoney(minimum)) · $100 minimum increment", systemImage: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("No further demo bids available")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(InventoryPalette.salvageTitle)
                    .accessibilityIdentifier("bidError")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .overlay(alignment: .top) {
            Rectangle().fill(InventoryPalette.lotNavy).frame(height: 3)
        }
        .vehicleDetailSurface()
    }

    private var auctionCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VehicleDetailCardHeading(title: "Auction snapshot", icon: "hammer")
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.bidState.currentBid == nil ? "STARTING BID" : "CURRENT BID")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                        money(viewModel.bidState.currentBid ?? vehicle.startingBid, size: 26)
                            .accessibilityIdentifier("currentBid")
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.bidState.bidCount) bids")
                            .font(.system(size: 13, weight: .semibold))
                            .accessibilityIdentifier("bidCount")
                        Text(reserveLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            if let minimum {
                HStack {
                    Text("Minimum next bid")
                    Spacer(minLength: 0)
                    Text(verbatim: VehicleDisplayFormatter.money(minimum)).fontWeight(.semibold)
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

    private func reviewCard(_ amount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VehicleDetailCardHeading(title: "Review demo bid", icon: "checklist")
            Text("Your bid").font(.system(size: 20, weight: .semibold))
            money(amount, size: 38)
            Divider()
            summaryLine("Current bid", value: VehicleDisplayFormatter.money(viewModel.bidState.currentBid ?? vehicle.startingBid))
            // A first bid is compared to the starting price; subsequent bids to the current price.
            summaryLine("Increase", value: VehicleDisplayFormatter.money(amount - (viewModel.bidState.currentBid ?? vehicle.startingBid)))
            summaryLine("Lot", value: vehicle.lot)
            HStack {
                Text("Reserve status").foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(reserveLabel).fontWeight(.semibold)
            }
            .font(.system(size: 12))
            .padding(12)
            .background(InventoryPalette.mist, in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(16)
        .vehicleDetailSurface()
    }

    private func successCard(_ state: BidState) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(InventoryPalette.cleanTitle)
                .frame(width: 52, height: 52)
                .background(InventoryPalette.liveBackground, in: Circle())
            Text("Demo bid saved")
                .font(.system(size: 20, weight: .semibold))
                .accessibilityIdentifier("bidSuccess")
            if let amount = state.currentBid { money(amount, size: 38) }
            Text(verbatim: VehicleDisplayFormatter.identity(vehicle))
                .font(.system(size: 14, weight: .semibold))
            Text("Lot \(vehicle.lot)").font(.system(size: 12)).foregroundStyle(.secondary)
            Divider()
            Text("Saved on this device. This is a simulated bid. No purchase has been made.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 26)
        .vehicleDetailSurface()
    }

    private var simulationNotice: some View {
        Label("Simulated bidding on this device. No purchase or payment is made.", systemImage: "flask")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actions(isLive: Bool) -> some View {
        VStack(spacing: 10) {
            switch viewModel.stage {
            case .editing:
                primaryButton("Review demo bid", icon: "arrow.right", identifier: "reviewBid", enabled: isLive && minimum != nil) {
                    amountFocused = false
                    viewModel.review()
                }
                Text("Review the amount before confirming")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            case .confirming:
                primaryButton("Confirm demo bid", icon: "checkmark", identifier: "confirmBid", enabled: isLive) { viewModel.confirm() }
                Button("Edit amount") { viewModel.edit() }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(InventoryPalette.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(InventoryPalette.navy.opacity(0.12), lineWidth: 1)
                    }
                    .buttonStyle(.plain)
            case .success:
                primaryButton("Done", icon: "checkmark", identifier: "dismissBidSuccess") { dismiss() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, amountFocused ? 8 : 16)
        .background(InventoryPalette.card)
        .overlay(alignment: .top) { Divider() }
    }

    private func primaryButton(_ title: LocalizedStringKey, icon: String, identifier: String,
                               enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: icon)
            }
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(InventoryPalette.card)
            .background(InventoryPalette.navy.opacity(enabled ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }

    private func summaryLine(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(verbatim: value).fontWeight(.semibold)
        }
        .font(.system(size: 12))
    }

    private func shortMoney(_ amount: Int) -> String {
        amount.formatted(.currency(code: "CAD").presentation(.narrow).precision(.fractionLength(0)))
    }

    private func money(_ amount: Int, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(verbatim: shortMoney(amount))
                .font(.system(size: size, weight: .semibold))
                .tracking(-1)
                .monospacedDigit()
            Text("CAD").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var reserveLabel: String {
        switch BidPolicy().reserve(for: vehicle, state: viewModel.bidState) {
        case .noReserve: String(localized: "No reserve")
        case .notMet: String(localized: "Reserve not met")
        case .met: String(localized: "Reserve met")
        }
    }

    private func incrementedAmount(by increment: Int) -> Int? {
        guard let minimum else { return nil }
        let current = max((try? BidPolicy().parse(viewModel.amount)) ?? minimum, minimum)
        let (amount, overflow) = current.addingReportingOverflow(increment)
        return overflow ? nil : amount
    }

    private func increaseAmount(by increment: Int) {
        guard let amount = incrementedAmount(by: increment) else { return }
        viewModel.amount = String(amount)
    }
}
