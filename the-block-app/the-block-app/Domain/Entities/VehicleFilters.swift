/// Optional criteria combine with each other and with the text search.
struct VehicleFilters: Equatable, Sendable {
    var make: String?
    var bodyStyle: String?
    var fuelType: String?
    var titleStatus: String?
    var province: String?
    var minimumYear: Int?
    var maximumOdometerKm: Int?

    var activeCount: Int {
        [make != nil, bodyStyle != nil, fuelType != nil, titleStatus != nil,
         province != nil, minimumYear != nil, maximumOdometerKm != nil]
            .filter { $0 }.count
    }

    func matches(_ vehicle: Vehicle) -> Bool {
        (make == nil || make == vehicle.make)
            && (bodyStyle == nil || bodyStyle == vehicle.bodyStyle)
            && (fuelType == nil || fuelType == vehicle.fuelType)
            && (titleStatus == nil || titleStatus == vehicle.titleStatus)
            && (province == nil || province == vehicle.province)
            && (minimumYear == nil || vehicle.year >= minimumYear!)
            && (maximumOdometerKm == nil || vehicle.odometerKm <= maximumOdometerKm!)
    }
}
