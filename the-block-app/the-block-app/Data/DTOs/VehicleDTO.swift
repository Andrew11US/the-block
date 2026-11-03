import Foundation

struct VehicleDTO: Decodable {
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
    let auctionTimezone: String
    let startingBid: Int
    let reservePrice: Int?
    let buyNowPrice: Int?
    let images: [String]
    let sellingDealership: String
    let lot: String
    let currentBid: Int?
    let bidCount: Int

    func toDomain() -> Vehicle {
        Vehicle(
            id: id,
            vin: vin,
            year: year,
            make: make,
            model: model,
            trim: trim,
            bodyStyle: bodyStyle,
            exteriorColor: exteriorColor,
            interiorColor: interiorColor,
            engine: engine,
            transmission: transmission,
            drivetrain: drivetrain,
            odometerKm: odometerKm,
            fuelType: fuelType,
            conditionGrade: conditionGrade,
            conditionReport: conditionReport,
            damageNotes: damageNotes,
            titleStatus: titleStatus,
            province: province,
            city: city,
            auctionStart: auctionStart,
            auctionEnd: auctionEnd,
            auctionSchedule: AuctionSchedule(start: auctionStart, end: auctionEnd, timezone: auctionTimezone),
            auctionTimezone: auctionTimezone,
            startingBid: startingBid,
            reservePrice: reservePrice,
            buyNowPrice: buyNowPrice,
            images: images,
            sellingDealership: sellingDealership,
            lot: lot,
            currentBid: currentBid,
            bidCount: bidCount
        )
    }
}
