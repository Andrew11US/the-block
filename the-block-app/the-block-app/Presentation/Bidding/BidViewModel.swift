import Foundation
import Observation

@MainActor
@Observable
final class BidViewModel {
    enum Stage: Equatable { case editing, confirming(Int), success(BidState) }
    let vehicle: Vehicle
    var amount: String
    private(set) var stage: Stage = .editing
    private(set) var errorMessage: String?
    private let now: () -> Date
    private let repository: any BidRepository
    private let placeBid: PlaceBid

    init(vehicle: Vehicle, repository: any BidRepository, now: @escaping () -> Date = Date.init) {
        self.now = now
        self.vehicle = vehicle
        self.repository = repository
        placeBid = PlaceBid(repository: repository)
        amount = BidPolicy().minimum(for: vehicle, state: repository.state(for: vehicle)).map(String.init) ?? ""
    }

    var bidState: BidState { repository.state(for: vehicle) }

    func review() {
        guard stage == .editing else { return }
        do {
            let parsed = try BidPolicy().parse(amount)
            try BidPolicy().validate(parsed, for: vehicle, state: bidState, now: now())
            errorMessage = nil
            stage = .confirming(parsed)
        } catch { errorMessage = Self.message(for: error) }
    }

    func edit() { stage = .editing }

    func confirm() {
        guard case .confirming(let amount) = stage else { return }
        do {
            let accepted = try placeBid(String(amount), for: vehicle)
            stage = .success(accepted)
        } catch {
            stage = .editing
            errorMessage = Self.message(for: error)
        }
    }

    static func message(for error: Error) -> String {
        switch error as? BidError {
        case .auctionNotStarted:
            String(localized: "This auction has not started. Bidding opens at the scheduled start time.")
        case .auctionEnded:
            String(localized: "This auction has ended. No further bids can be placed.")
        case .auctionUnavailable:
            String(localized: "The auction schedule is unavailable. Bidding is disabled.")
        case .invalidAmount:
            String(localized: "Enter a whole-dollar amount using digits only, without punctuation.")
        case .amountTooLarge:
            String(localized: "That amount is too large. Enter a smaller whole-dollar amount.")
        case .belowMinimum(let minimum):
            String(localized: "Enter at least \(VehicleDisplayFormatter.money(minimum)).")
        case .limitReached:
            String(localized: "No further demo bids can be placed on this vehicle.")
        default:
            String(localized: "Your demo bid could not be saved. Nothing changed. Please try again.")
        }
    }
}
