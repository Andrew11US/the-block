import SwiftUI

struct DealershipSection: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VehicleDetailCardHeading(title: "Selling dealership", icon: "storefront")
            Text(verbatim: vehicle.sellingDealership)
                .font(.system(size: 14, weight: .semibold))
            Label("\(vehicle.city), \(vehicle.province)", systemImage: "mappin.and.ellipse")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(InventoryPalette.navy)
        .padding(16)
        .vehicleDetailSurface()
    }
}
