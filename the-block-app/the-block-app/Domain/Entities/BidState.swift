struct BidState: Codable, Equatable, Sendable {
    let currentBid: Int?
    let bidCount: Int

    static func source(_ vehicle: Vehicle) -> BidState {
        BidState(currentBid: vehicle.currentBid, bidCount: vehicle.bidCount)
    }

    static func resolve(_ vehicle: Vehicle, override: BidState?) -> BidState {
        guard let override, let amount = override.currentBid,
              amount >= (vehicle.currentBid ?? vehicle.startingBid),
              override.bidCount > vehicle.bidCount else { return source(vehicle) }
        return override
    }
}

enum ReserveStatus: Equatable { case noReserve, notMet, met }

enum BidError: Error, Equatable {
    case invalidAmount
    case amountTooLarge
    case belowMinimum(Int)
    case limitReached
    case auctionNotStarted
    case auctionEnded
    case auctionUnavailable
    case persistence
}
