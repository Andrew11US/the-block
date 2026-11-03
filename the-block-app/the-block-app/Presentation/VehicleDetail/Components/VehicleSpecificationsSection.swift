import SwiftUI

struct VehicleSpecificationsSection: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VehicleDetailCardHeading(title: "Specifications", icon: "gearshape")
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 16) {
                specification("Odometer", value: "\(vehicle.odometerKm.formatted()) km", icon: "speedometer")
                specification("Body style", value: vehicle.bodyStyle.uppercased() == "SUV" ? "SUV" : vehicle.bodyStyle.capitalized, icon: "car.side")
                specification("Engine", value: vehicle.engine, icon: "engine.combustion")
                specification("Transmission", value: vehicle.transmission.capitalized, icon: "gearshape.2")
                specification("Drivetrain", value: vehicle.drivetrain, icon: "arrow.triangle.branch")
                specification("Fuel", value: vehicle.fuelType.capitalized, icon: "fuelpump")
                specification("Exterior colour", value: vehicle.exteriorColor, icon: "paintbrush")
                specification("Interior colour", value: vehicle.interiorColor, icon: "carseat.right")
            }
        }
        .padding(16)
        .vehicleDetailSurface()
    }

    private func specification(_ title: LocalizedStringKey, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(InventoryPalette.navy)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
