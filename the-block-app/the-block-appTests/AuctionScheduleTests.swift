import Foundation
import Testing
@testable import the_block_app

@MainActor
struct AuctionScheduleTests {
    @Test func exactStartOpensAndExactEndClosesBidding() throws {
        let schedule = try #require(AuctionSchedule(start: "2026-11-02T18:00:00", end: "2026-11-03T18:00:00", timezone: "America/Toronto"))
        #expect(schedule.start == Date(timeIntervalSince1970: 1793660400))
        #expect(schedule.status(at: schedule.start.addingTimeInterval(-1)) == .upcoming)
        #expect(schedule.status(at: schedule.start) == .live)
        #expect(schedule.status(at: schedule.end.addingTimeInterval(-1)) == .live)
        #expect(schedule.status(at: schedule.end) == .ended)
    }

    @Test func statusTimelineOnlyWakesAtFutureTransitions() throws {
        let schedule = try #require(AuctionSchedule(start: "2026-11-02T18:00:00", end: "2026-11-03T18:00:00", timezone: "America/Toronto"))
        let before = schedule.start.addingTimeInterval(-1)
        #expect(schedule.timelineDates(from: before) == [before, schedule.start, schedule.end])
        #expect(schedule.timelineDates(from: schedule.start) == [schedule.start, schedule.end])
        #expect(schedule.timelineDates(from: schedule.end) == [schedule.end])
    }

    @Test func loadedVehiclesReuseParsedSchedules() async throws {
        let vehicles = try await AppDependencies().loadInventory()
        #expect(vehicles.count == 200)
        for vehicle in vehicles {
            let expected = AuctionSchedule(start: vehicle.auctionStart, end: vehicle.auctionEnd,
                                           timezone: vehicle.auctionTimezone)
            #expect(vehicle.auctionSchedule == expected)
            #expect(AuctionSchedule(vehicle: vehicle) == expected)
        }
    }

    @Test func invalidSchedulesFailClosed() {
        for (start, end, zone) in [
            ("2026-02-30T18:00:00", "2026-03-01T18:00:00", "America/Toronto"),
            ("2026-11-02T18:00:00", "2026-11-02T18:00:00", "America/Toronto"),
            ("2026-11-03T18:00:00", "2026-11-02T18:00:00", "America/Toronto"),
            ("2026-11-02T18:00:00", "2026-11-03T18:00:00", "Invalid/Zone")
        ] {
            #expect(AuctionSchedule(start: start, end: end, timezone: zone) == nil)
        }
    }

    @Test func timezoneObservesDaylightSavingTransition() throws {
        let schedule = try #require(AuctionSchedule(start: "2026-10-31T18:00:00", end: "2026-11-01T18:00:00", timezone: "America/Toronto"))
        #expect(schedule.end.timeIntervalSince(schedule.start) == 25 * 3600)
    }

    @Test func repositoryRejectsOutsideWindowWithoutWriting() async throws {
        let vehicle = try #require(try await AppDependencies().loadInventory().first)
        let schedule = try #require(AuctionSchedule(vehicle: vehicle))
        var now = schedule.start.addingTimeInterval(-1)
        let source = MemoryBidDataSource()
        let repository = LocalBidRepository(source: source, now: { now })
        let minimum = try #require(BidPolicy().minimum(for: vehicle, state: .source(vehicle)))
        #expect(throws: BidError.auctionNotStarted) { try repository.submit(minimum, for: vehicle) }
        now = schedule.end
        #expect(throws: BidError.auctionEnded) { try repository.submit(minimum, for: vehicle) }
        #expect(source.writeCount == 0)
        #expect(repository.state(for: vehicle) == .source(vehicle))
        now = schedule.start
        #expect(try repository.submit(minimum, for: vehicle).currentBid == minimum)
        #expect(source.writeCount == 1)
    }

    @Test func confirmationRechecksClockAfterReview() async throws {
        let vehicle = try #require(try await AppDependencies().loadInventory().first)
        let schedule = try #require(AuctionSchedule(vehicle: vehicle))
        var now = schedule.end.addingTimeInterval(-1)
        let source = MemoryBidDataSource()
        let repository = LocalBidRepository(source: source, now: { now })
        let model = BidViewModel(vehicle: vehicle, repository: repository, now: { now })
        model.review()
        guard case .confirming = model.stage else { Issue.record("Expected review before closing"); return }
        now = schedule.end
        model.confirm()
        #expect(model.stage == .editing)
        #expect(model.errorMessage == BidViewModel.message(for: BidError.auctionEnded))
        #expect(source.writeCount == 0)
        model.review()
        #expect(model.stage == .editing)
    }
}
