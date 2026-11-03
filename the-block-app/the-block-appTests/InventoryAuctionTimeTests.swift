import Foundation
import Testing
@testable import the_block_app

@MainActor
struct InventoryAuctionTimeTests {
    @Test func preservesSuppliedWallClockTime() {
        let text = InventoryAuctionTime.display("2026-04-05T19:00:00", locale: Locale(identifier: "en_CA"))
        #expect(text != nil)
        #expect(text?.contains("Apr") == true)
        #expect(text?.contains("19:00") == true)
    }

    @Test func rejectsMissingMalformedAndImpossibleDates() {
        for source in ["", "not-a-date", "2026-02-30T19:00:00", "2026-04-05T19:00:00Z"] {
            #expect(InventoryAuctionTime.display(source) == nil)
        }
    }
}
