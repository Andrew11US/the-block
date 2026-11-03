import Foundation

/// Formatting belongs to presentation; auction policy stays in Domain.
enum VehicleDisplayFormatter {
    static func identity(_ vehicle: Vehicle) -> String {
        "\(vehicle.year) \(vehicle.make) \(vehicle.model)"
    }

    static func money(_ amount: Int) -> String {
        amount.formatted(.currency(code: "CAD").presentation(.isoCode).precision(.fractionLength(0)))
    }
}
