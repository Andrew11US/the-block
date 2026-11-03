/// Inventory values with auction timestamps interpreted in the supplied timezone.
struct Vehicle: Identifiable, Equatable, Sendable {
    let id: String
    let vin: String
    let year: Int
    let make: String
    let model: String
    let trim: String
    let bodyStyle: String
    let exteriorColor: String
    let interiorColor: String
    let engine: String
    let transmission: String
    let drivetrain: String
    let odometerKm: Int
    let fuelType: String
    let conditionGrade: Double
    let conditionReport: String
    let damageNotes: [String]
    let titleStatus: String
    let province: String
    let city: String
    let auctionStart: String
    let auctionEnd: String
    /// Parsed once during DTO mapping, shared by all presentation and policy paths.
    let auctionSchedule: AuctionSchedule?
    let auctionTimezone: String
    let startingBid: Int
    let reservePrice: Int?
    let buyNowPrice: Int?
    let images: [String]
    let sellingDealership: String
    let lot: String
    let currentBid: Int?
    let bidCount: Int
}
