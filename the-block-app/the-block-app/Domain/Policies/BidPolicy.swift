import Foundation

struct BidPolicy {
    func parse(_ input: String) throws -> Int {
        let digits = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !digits.isEmpty, digits.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw BidError.invalidAmount
        }
        guard let amount = Int(digits) else { throw BidError.amountTooLarge }
        return amount
    }

    func minimum(for vehicle: Vehicle, state: BidState) -> Int? {
        guard let current = state.currentBid else { return vehicle.startingBid }
        let (amount, overflow) = current.addingReportingOverflow(100)
        return overflow ? nil : max(vehicle.startingBid, amount)
    }

    func validate(_ amount: Int, for vehicle: Vehicle, state: BidState, now: Date = Date()) throws {
        try validateAuction(for: vehicle, at: now)
        guard let minimum = minimum(for: vehicle, state: state) else { throw BidError.limitReached }
        guard amount >= minimum else { throw BidError.belowMinimum(minimum) }
        guard state.bidCount < Int.max else { throw BidError.limitReached }
    }

    func reserve(for vehicle: Vehicle, state: BidState) -> ReserveStatus {
        guard let threshold = vehicle.reservePrice else { return .noReserve }
        return (state.currentBid ?? 0) >= threshold ? .met : .notMet
    }
}

extension BidPolicy {
    func validateAuction(for vehicle: Vehicle, at now: Date) throws {
        switch AuctionSchedule(vehicle: vehicle)?.status(at: now) {
        case .live: return
        case .upcoming: throw BidError.auctionNotStarted
        case .ended: throw BidError.auctionEnded
        case nil: throw BidError.auctionUnavailable
        }
    }
}
