/// Every query word must occur in the vehicle's searchable identity.
struct SearchVehicles {
    func callAsFunction(_ vehicles: [Vehicle], query: String, filters: VehicleFilters = .init()) -> [Vehicle] {
        let words = query.lowercased().split(whereSeparator: { $0.isWhitespace })
        return vehicles.filter { vehicle in
            guard filters.matches(vehicle) else { return false }
            let text = [vehicle.make, vehicle.model, String(vehicle.year), vehicle.vin, vehicle.lot]
                .joined(separator: " ").lowercased()
            return words.allSatisfy { text.contains($0) }
        }
    }
}
