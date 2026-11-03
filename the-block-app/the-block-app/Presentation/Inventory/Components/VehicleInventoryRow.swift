import SwiftUI

struct VehicleInventoryRow: View {
    let vehicle: Vehicle
    let bidState: BidState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    photo
                    summary
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    photo
                    summary
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var photo: some View {
        VehicleImage(url: vehicle.images.first, requiresScrollVisibility: true)
            .frame(width: 88, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: VehicleDisplayFormatter.identity(vehicle))
                .font(.headline)
            Text(verbatim: vehicle.trim)
                .font(.subheadline)
            Text("\(vehicle.odometerKm.formatted()) km · \(vehicle.city), \(vehicle.province)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TitleStatusBadge(status: vehicle.titleStatus)
            VStack(alignment: .leading, spacing: 2) {
                if let currentBid = bidState.currentBid {
                    Text("Current bid: \(VehicleDisplayFormatter.money(currentBid))")
                } else {
                    Text("Starting bid: \(VehicleDisplayFormatter.money(vehicle.startingBid))")
                }
                Text("Lot \(vehicle.lot)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}
