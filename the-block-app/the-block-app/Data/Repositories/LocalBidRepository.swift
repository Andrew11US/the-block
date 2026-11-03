import Foundation

@MainActor
final class LocalBidRepository: BidRepository {
    private struct SavedBids: Codable {
        let version: Int
        let overrides: [String: BidState]
    }

    private(set) var states: [String: BidState] = [:]
    private(set) var restorationFailed = false
    private let now: () -> Date
    private let source: any LocalBidDataSource
    private var observers: [UUID: AsyncStream<[String: BidState]>.Continuation] = [:]

    init(source: any LocalBidDataSource, now: @escaping () -> Date = Date.init) {
        self.now = now
        self.source = source
        do {
            if let data = try source.read() {
                let saved = try JSONDecoder().decode(SavedBids.self, from: data)
                guard saved.version == 1,
                      saved.overrides.values.allSatisfy({ ($0.currentBid ?? -1) >= 0 && $0.bidCount > 0 }) else {
                    throw BidError.persistence
                }
                states = saved.overrides
            }
        } catch {
            restorationFailed = true
        }
    }

    func state(for vehicle: Vehicle) -> BidState {
        BidState.resolve(vehicle, override: states[vehicle.id])
    }

    func updates() -> AsyncStream<[String: BidState]> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            observers[id] = continuation
            continuation.yield(states)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in _ = self?.observers.removeValue(forKey: id) }
            }
        }
    }

    func submit(_ amount: Int, for vehicle: Vehicle) throws -> BidState {
        let latest = state(for: vehicle)
        try BidPolicy().validate(amount, for: vehicle, state: latest, now: now())
        let accepted = BidState(currentBid: amount, bidCount: latest.bidCount + 1)
        var updated = states
        updated[vehicle.id] = accepted
        try save(updated)
        return accepted
    }

    func reset() throws {
        try save([:])
    }

    private func save(_ updated: [String: BidState]) throws {
        do {
            let data = try JSONEncoder().encode(SavedBids(version: 1, overrides: updated))
            try source.write(data)
        } catch {
            throw BidError.persistence
        }
        states = updated
        restorationFailed = false
        for observer in observers.values { observer.yield(states) }
    }
}
