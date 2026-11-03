import Foundation
import Testing
@testable import the_block_app

private let demoBidTime = Date(timeIntervalSince1970: 1793667600) // November 2, 2026, 20:00 Toronto

@MainActor
struct BiddingTests {
    private func inventory() async throws -> [Vehicle] { try await AppDependencies().loadInventory() }

    @Test(arguments: ["", " ", "-1", "+100", "1.5", "1,000", "$100", "1 000", "١٢٣", "1e3"])
    func malformedAmountsAreRejected(_ input: String) {
        #expect(throws: BidError.invalidAmount) { try BidPolicy().parse(input) }
    }

    @Test func overflowIsRejectedAndWhitespaceIsTrimmed() throws {
        #expect(throws: BidError.amountTooLarge) { try BidPolicy().parse(String(repeating: "9", count: 80)) }
        #expect(try BidPolicy().parse(" 21000\n") == 21000)
    }

    @Test func firstBidAndExistingBidBoundaries() async throws {
        let vehicles = try await inventory()
        let unbid = try #require(vehicles.first { $0.currentBid == nil })
        let active = try #require(vehicles.first { $0.currentBid != nil })
        let repository = LocalBidRepository(source: MemoryBidDataSource(), now: { demoBidTime })
        #expect(throws: BidError.belowMinimum(unbid.startingBid)) {
            try repository.submit(unbid.startingBid - 1, for: unbid)
        }
        let accepted = try repository.submit(unbid.startingBid, for: unbid)
        #expect(accepted.currentBid == unbid.startingBid)
        #expect(accepted.bidCount == unbid.bidCount + 1)
        let next = try #require(active.currentBid) + 100
        #expect(throws: BidError.belowMinimum(next)) { try repository.submit(next - 1, for: active) }
        #expect(try repository.submit(next, for: active).currentBid == next)
        #expect(repository.state(for: unbid) == accepted)
    }

    @Test func reserveStatusCrossesThresholdWithoutRevealingPrice() async throws {
        let vehicles = try await inventory()
        let vehicle = try #require(vehicles.first { $0.reservePrice != nil && ($0.currentBid ?? 0) < $0.reservePrice! })
        let repository = LocalBidRepository(source: MemoryBidDataSource(), now: { demoBidTime })
        #expect(BidPolicy().reserve(for: vehicle, state: repository.state(for: vehicle)) == .notMet)
        let amount = max(try #require(vehicle.reservePrice), try #require(BidPolicy().minimum(for: vehicle, state: .source(vehicle))))
        let state = try repository.submit(amount, for: vehicle)
        #expect(BidPolicy().reserve(for: vehicle, state: state) == .met)
        let noReserve = try #require(vehicles.first { $0.reservePrice == nil })
        #expect(BidPolicy().reserve(for: noReserve, state: .source(noReserve)) == .noReserve)
    }

    @Test func restoreResetAndCorruptData() async throws {
        let vehicle = try #require(try await inventory().first)
        let source = MemoryBidDataSource()
        let repository = LocalBidRepository(source: source, now: { demoBidTime })
        let amount = try #require(BidPolicy().minimum(for: vehicle, state: .source(vehicle)))
        let accepted = try repository.submit(amount, for: vehicle)
        let restored = LocalBidRepository(source: source, now: { demoBidTime })
        #expect(restored.state(for: vehicle) == accepted)
        try ResetDemoBids(repository: restored)()
        #expect(LocalBidRepository(source: source, now: { demoBidTime }).state(for: vehicle) == .source(vehicle))
        source.data = Data("corrupt".utf8)
        let corrupt = LocalBidRepository(source: source, now: { demoBidTime })
        #expect(corrupt.restorationFailed)
        #expect(corrupt.state(for: vehicle) == .source(vehicle))
    }

    @Test func failedSaveAndResetLeaveStateUnchanged() async throws {
        let vehicle = try #require(try await inventory().first)
        let source = MemoryBidDataSource()
        let repository = LocalBidRepository(source: source, now: { demoBidTime })
        source.failWrites = true
        let amount = try #require(BidPolicy().minimum(for: vehicle, state: .source(vehicle)))
        #expect(throws: BidError.persistence) { try repository.submit(amount, for: vehicle) }
        #expect(repository.state(for: vehicle) == .source(vehicle))
        source.failWrites = false
        let accepted = try repository.submit(amount, for: vehicle)
        let saved = source.data
        source.failWrites = true
        #expect(throws: BidError.persistence) { try repository.reset() }
        #expect(repository.state(for: vehicle) == accepted)
        #expect(source.data == saved)
    }

    @Test func reviewCancelAndDuplicateConfirmation() async throws {
        let vehicle = try #require(try await inventory().first)
        let source = MemoryBidDataSource()
        let repository = LocalBidRepository(source: source, now: { demoBidTime })
        let model = BidViewModel(vehicle: vehicle, repository: repository, now: { demoBidTime })
        model.review()
        #expect(repository.state(for: vehicle) == .source(vehicle))
        model.edit()
        #expect(source.writeCount == 0)
        model.review()
        model.confirm()
        model.confirm()
        #expect(source.writeCount == 1)
        #expect(repository.state(for: vehicle).bidCount == vehicle.bidCount + 1)
        guard case .success = model.stage else { Issue.record("Expected saved confirmation"); return }
    }

    @Test func staleConfirmationRevalidatesLatestState() async throws {
        let vehicle = try #require(try await inventory().first)
        let repository = LocalBidRepository(source: MemoryBidDataSource(), now: { demoBidTime })
        let model = BidViewModel(vehicle: vehicle, repository: repository, now: { demoBidTime })
        model.review()
        let minimum = try #require(BidPolicy().minimum(for: vehicle, state: .source(vehicle)))
        let newer = try repository.submit(minimum, for: vehicle)
        model.confirm()
        #expect(model.stage == .editing)
        #expect(model.errorMessage != nil)
        #expect(repository.state(for: vehicle) == newer)
    }

    @Test func updatesPublishOnlyCommittedStates() async throws {
        let vehicle = try #require(try await inventory().first)
        let repository = LocalBidRepository(source: MemoryBidDataSource(), now: { demoBidTime })
        var first = repository.updates().makeAsyncIterator()
        var second = repository.updates().makeAsyncIterator()
        #expect(await first.next() == [:])
        #expect(await second.next() == [:])
        let amount = try #require(BidPolicy().minimum(for: vehicle, state: .source(vehicle)))
        let state = try repository.submit(amount, for: vehicle)
        #expect(await first.next()?[vehicle.id] == state)
        #expect(await second.next()?[vehicle.id] == state)
        try repository.reset()
        #expect(await first.next() == [:])
        #expect(await second.next() == [:])
    }

    @Test func integerLimitDoesNotOverflow() async throws {
        let vehicle = try #require(try await inventory().first)
        let state = BidState(currentBid: Int.max, bidCount: Int.max)
        #expect(BidPolicy().minimum(for: vehicle, state: state) == nil)
        #expect(throws: BidError.limitReached) { try BidPolicy().validate(Int.max, for: vehicle, state: state, now: demoBidTime) }
    }

    @Test func fileSourcePersistsAtomically() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + "/bids.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let source = FileBidDataSource(url: url)
        #expect(try source.read() == nil)
        let vehicle = try #require(try await inventory().first)
        let repository = LocalBidRepository(source: source, now: { demoBidTime })
        let amount = try #require(BidPolicy().minimum(for: vehicle, state: .source(vehicle)))
        let state = try PlaceBid(repository: repository)(String(amount), for: vehicle)
        #expect(LocalBidRepository(source: source, now: { demoBidTime }).state(for: vehicle) == state)
    }
}

@MainActor
struct BiddingRecoveryTests {
    @Test func unsupportedAndInvalidStorageFallBack() {
        let source = MemoryBidDataSource()
        for json in ["{\"version\":2,\"overrides\":{}}",
                     "{\"version\":1,\"overrides\":{\"bad\":{\"currentBid\":-10,\"bidCount\":1}}}"] {
            source.data = Data(json.utf8)
            let repository = LocalBidRepository(source: source, now: { demoBidTime })
            #expect(repository.restorationFailed)
            #expect(repository.states.isEmpty)
        }
    }

    @Test func failedConfirmationReturnsToEditingWithoutSuccess() async throws {
        let vehicle = try #require(try await AppDependencies().loadInventory().first)
        let source = MemoryBidDataSource()
        source.failWrites = true
        let repository = LocalBidRepository(source: source, now: { demoBidTime })
        let model = BidViewModel(vehicle: vehicle, repository: repository, now: { demoBidTime })
        model.review()
        model.confirm()
        #expect(model.stage == .editing)
        #expect(model.errorMessage != nil)
        #expect(repository.state(for: vehicle) == .source(vehicle))
        #expect(source.writeCount == 0)
    }

    @Test func inventoryResetRestoresSourceAndReportsFailure() async throws {
        let vehicle = try #require(try await AppDependencies().loadInventory().first)
        let source = MemoryBidDataSource()
        let repository = LocalBidRepository(source: source, now: { demoBidTime })
        let minimum = try #require(BidPolicy().minimum(for: vehicle, state: .source(vehicle)))
        let accepted = try repository.submit(minimum, for: vehicle)
        let model = InventoryViewModel(loadInventory: AppDependencies().loadInventory, bidRepository: repository)
        #expect(model.bidState(for: vehicle) == accepted)
        source.failWrites = true
        model.resetBids()
        #expect(model.resetError != nil)
        #expect(model.bidState(for: vehicle) == accepted)
        source.failWrites = false
        model.resetBids()
        #expect(model.resetError == nil)
        #expect(model.bidState(for: vehicle) == .source(vehicle))
    }
}
