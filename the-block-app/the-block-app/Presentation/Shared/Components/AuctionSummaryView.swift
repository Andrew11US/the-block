import SwiftUI

struct AuctionSummaryView: View {
    let vehicle: Vehicle
    let state: BidState

    // A fresh Date.now in body would reschedule the timeline during layout.
    @State private var timelineOrigin = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.explicit(AuctionSchedule(vehicle: vehicle)?.timelineDates(from: timelineOrigin) ?? [timelineOrigin])) { context in
                AuctionStatusFooter(vehicle: vehicle, now: context.date)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            if let currentBid = state.currentBid {
                Text("Current bid: \(VehicleDisplayFormatter.money(currentBid))")
                    .font(.title3.bold())
                    .accessibilityIdentifier("currentBid")
            } else {
                Text("Starting bid: \(VehicleDisplayFormatter.money(vehicle.startingBid))")
                    .font(.title3.bold())
            }
            Text("\(state.bidCount) bids")
                .accessibilityIdentifier("bidCount")
            switch BidPolicy().reserve(for: vehicle, state: state) {
            case .noReserve: Text("No reserve")
            case .notMet: Text("Reserve not met")
            case .met: Text("Reserve met")
            }
            if let minimum = BidPolicy().minimum(for: vehicle, state: state) {
                Text("Minimum next bid: \(VehicleDisplayFormatter.money(minimum))")
            } else {
                Text("No further demo bids available")
            }
            Text("Simulated bidding · CAD · \(VehicleDisplayFormatter.money(100)) minimum increment after the first bid")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
