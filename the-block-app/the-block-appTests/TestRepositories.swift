import Foundation
@testable import the_block_app

@MainActor
final class EmptyBidRepository: BidRepository {
    var states: [String: BidState] = [:]
    var restorationFailed = false
    func state(for vehicle: Vehicle) -> BidState { .source(vehicle) }
    func updates() -> AsyncStream<[String: BidState]> { AsyncStream { $0.yield([:]); $0.finish() } }
    func submit(_ amount: Int, for vehicle: Vehicle) throws -> BidState { throw BidError.persistence }
    func reset() throws {}
}

@MainActor
final class MemoryBidDataSource: LocalBidDataSource {
    var data: Data?
    var failWrites = false
    var writeCount = 0
    func read() throws -> Data? { data }
    func write(_ data: Data) throws {
        if failWrites { throw BidError.persistence }
        self.data = data
        writeCount += 1
    }
}
