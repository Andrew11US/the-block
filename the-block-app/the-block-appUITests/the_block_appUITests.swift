import XCTest

final class InventoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testInventoryScrollingPerformance() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline-images"]
        app.launch()
        XCTAssertTrue(app.buttons["inventoryBid-A-0001"].waitForExistence(timeout: 10))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric], options: options) {
            app.swipeUp(velocity: .fast)
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }

    @MainActor
    func testQuickFiltersThenScrolling() {
        verifyQuickFiltersThenScrolling(offline: true)
    }

    @MainActor
    func testQuickFiltersWithNormalLaunch() {
        verifyQuickFiltersThenScrolling(offline: false)
    }

    @MainActor
    func testQuickFilterCanBeClearedWithNormalLaunch() {
        let app = XCUIApplication()
        app.launch()
        let ended = app.buttons["auctionFilter-ended"]
        XCTAssertTrue(ended.waitForExistence(timeout: 10))
        ended.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: ended)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        XCTAssertNotEqual(app.staticTexts["resultCount"].label, "200 of 200 vehicles")
        ended.tap()
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == false"), object: ended)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 5), .completed)
        XCTAssertEqual(app.staticTexts["resultCount"].label, "200 of 200 vehicles")
        app.buttons["showWatchlist"].tap()
        XCTAssertTrue(app.buttons["closeWatchlist"].waitForExistence(timeout: 5))
        app.buttons["closeWatchlist"].tap()
    }

    @MainActor
    private func verifyQuickFiltersThenScrolling(offline: Bool) {
        let app = XCUIApplication()
        app.launchArguments = offline ? ["--ui-testing", "--offline-images"] : []
        app.launch()
        for (filter, label) in [("upcoming", "Upcoming"), ("ended", "Auction ended"), ("live", "Live auction")] {
            let button = app.buttons["auctionFilter-\(filter)"]
            // Fast swipes need not travel equal distances. Restore the section
            // header explicitly before selecting another quick filter.
            for _ in 0..<6 {
                if button.exists && button.isHittable { break }
                app.swipeDown(velocity: .fast)
            }
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
            XCTAssertNotEqual(app.staticTexts["resultCount"].label, "200 of 200 vehicles")
            XCTAssertTrue(app.staticTexts[label].firstMatch.waitForExistence(timeout: 5))
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }

    @MainActor
    func testAuctionStatusFootersAndBidAvailability() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline-images"]
        for (lot, label, canBid) in [("A-0001", "Live auction", true),
                                      ("C-0021", "Upcoming", false),
                                      ("D-0031", "Auction ended", false)] {
            // Start each status check with an empty native search field. Clearing
            // a collapsed toolbar search can leave stale text in UI automation.
            app.terminate()
            app.launch()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 10))
            search.tap()
            search.typeText(lot + "\n")
            let bid = app.buttons["inventoryBid-\(lot)"]
            XCTAssertTrue(bid.waitForExistence(timeout: 5))
            XCTAssertEqual(bid.isEnabled, canBid)
            XCTAssertTrue(app.staticTexts[label].exists)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Auction status \(lot)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    @MainActor
    func testWatchlistSaveInspectPersistAndRemove() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline-images", "--reset-watchlist"]
        app.launch()
        let watchlist = app.buttons["showWatchlist"]
        XCTAssertTrue(watchlist.waitForExistence(timeout: 10))
        watchlist.tap()
        XCTAssertTrue(app.staticTexts["Your watchlist is empty"].waitForExistence(timeout: 5))
        app.buttons["closeWatchlist"].tap()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("A-0001")
        let heart = app.buttons["watchlist-A-0001"]
        XCTAssertTrue(heart.waitForExistence(timeout: 5))
        heart.tap()
        XCTAssertEqual(heart.value as? String, "Saved")
        XCTAssertFalse(app.staticTexts["vehicleIdentity"].exists)
        search.buttons["Clear text"].tap()
        app.buttons["close"].tap()
        watchlist.tap()
        let savedVehicle = app.descendants(matching: .any).matching(identifier: "savedVehicle-A-0001").firstMatch
        XCTAssertTrue(savedVehicle.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved vehicles watchlist"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        savedVehicle.tap()
        XCTAssertTrue(app.staticTexts["vehicleIdentity"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["vehicleIdentity"].label, "2025 Mazda CX-5")

        app.terminate()
        app.launchArguments = ["--ui-testing", "--offline-images"]
        app.launch()
        XCTAssertTrue(watchlist.waitForExistence(timeout: 10))
        watchlist.tap()
        XCTAssertTrue(savedVehicle.waitForExistence(timeout: 5))
        app.collectionViews["watchlistVehicles"].buttons["watchlist-A-0001"].tap()
        XCTAssertTrue(app.staticTexts["Your watchlist is empty"].waitForExistence(timeout: 5))
        app.buttons["closeWatchlist"].tap()
        XCTAssertEqual(app.buttons["watchlist-A-0001"].value as? String, "Not saved")
    }

    @MainActor
    func testFiltersApplyCancelAndReset() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline-images"]
        app.launch()
        let filters = app.buttons["searchFilters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
        filters.tap()
        app.buttons["filterMake"].tap()
        app.buttons["Mazda"].tap()
        let sheetScreenshot = XCTAttachment(screenshot: app.screenshot())
        sheetScreenshot.name = "Search filter sheet"
        sheetScreenshot.lifetime = .keepAlways
        add(sheetScreenshot)
        app.buttons["applyFilters"].tap()
        XCTAssertEqual(filters.value as? String, "1 active")
        XCTAssertFalse(app.staticTexts["200 of 200 vehicles"].exists)
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("A-0001")
        XCTAssertTrue(app.staticTexts["1 of 200 vehicles"].waitForExistence(timeout: 5))
        search.buttons["Clear text"].tap()
        app.buttons["close"].tap()

        filters.tap()
        app.buttons["filterMake"].tap()
        app.buttons["Nissan"].tap()
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertEqual(filters.value as? String, "1 active")

        filters.tap()
        app.buttons["resetFilters"].tap()
        XCTAssertFalse(app.buttons["applyFilters"].exists)
        XCTAssertEqual(filters.value as? String, "0 active")
        XCTAssertTrue(app.staticTexts["200 of 200 vehicles"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchSelectionAndClear() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline-images"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        let title = app.navigationBars["The Block"].staticTexts["The Block"]
        let expandedTitleHeight = title.frame.height
        let filter = app.buttons["searchFilters"]
        XCTAssertGreaterThan(search.frame.minY, app.frame.height / 2)
        XCTAssertLessThan(filter.frame.maxX, search.frame.minX)
        let expandedScreenshot = XCTAttachment(screenshot: app.screenshot())
        expandedScreenshot.name = "Native large inventory title"
        expandedScreenshot.lifetime = .keepAlways
        add(expandedScreenshot)
        app.collectionViews.firstMatch.swipeUp()
        XCTAssertTrue(title.isHittable)
        XCTAssertLessThan(title.frame.height, expandedTitleHeight)
        XCTAssertLessThan(title.frame.maxY, search.frame.minY)
        let headerScreenshot = XCTAttachment(screenshot: app.screenshot())
        headerScreenshot.name = "Inventory header after scrolling"
        headerScreenshot.lifetime = .keepAlways
        add(headerScreenshot)
        search.tap()
        search.typeText("cg2uaf4t8lrbbvwjy")
        let result = app.descendants(matching: .any).matching(identifier: "vehicle-A-0001").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 of 200 vehicles"].waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.staticTexts["vehicleIdentity"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["vehicleIdentity"].label, "2025 Mazda CX-5")
        let vin = app.descendants(matching: .any).matching(identifier: "vehicleVIN").firstMatch
        XCTAssertTrue(vin.exists)
        XCTAssertEqual(vin.label, "VIN · CG2UAF4T8LRBBVWJY")
        app.navigationBars.buttons.firstMatch.tap()
        let clear = search.buttons["Clear text"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(app.staticTexts["200 of 200 vehicles"].waitForExistence(timeout: 5))

        search.tap()
        search.typeText("no-matching-vehicle")
        XCTAssertTrue(app.staticTexts["No vehicles found"].waitForExistence(timeout: 5))
        app.buttons["clearSearch"].tap()
        XCTAssertTrue(app.staticTexts["200 of 200 vehicles"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testInspectSalvageVehicle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline-images"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("FCDBJZZV9APMK4UG8")
        let result = app.descendants(matching: .any).matching(identifier: "vehicle-A-0006").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.staticTexts["vehicleIdentity"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["vehicleIdentity"].label, "2021 BMW 3 Series")
        reveal(app.buttons["Next photo"], in: app)
        app.buttons["Next photo"].tap()
        let secondPhoto = app.buttons["Photo 2 of 5"]
        let selectedPhoto = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: secondPhoto)
        XCTAssertEqual(XCTWaiter.wait(for: [selectedPhoto], timeout: 5), .completed)
        reveal(app.staticTexts["conditionReport"], in: app)
        XCTAssertTrue(app.staticTexts["Salvage title"].exists)
        XCTAssertEqual(app.staticTexts["conditionReport"].label,
                       "Vehicle has substantial damage. Sold as-is. Recommended for parts or significant rebuild only.")
        reveal(app.staticTexts["Paint touch-up on hood (rock chips)"], in: app)
        XCTAssertTrue(app.staticTexts["Paint touch-up on hood (rock chips)"].exists)
    }

    @MainActor
    func testDemoBidCancelValidationPersistenceAndReset() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline-images"]
        app.launch()
        XCTAssertTrue(app.buttons["resetDemoBids"].waitForExistence(timeout: 10))
        app.buttons["resetDemoBids"].tap()
        confirmResetDemoBids(in: app)

        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("CG2UAF4T8LRBBVWJY")
        let row = app.descendants(matching: .any).matching(identifier: "vehicle-A-0001").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["placeBid"].waitForExistence(timeout: 5))
        app.buttons["placeBid"].tap()
        XCTAssertTrue(app.textFields["bidAmount"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "currentBid").matching(NSPredicate(format: "label CONTAINS %@", "21,000")).firstMatch.waitForExistence(timeout: 5))

        app.buttons["placeBid"].tap()
        let amount = app.textFields["bidAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "1")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["reviewBid"].isHittable)
        app.buttons["reviewBid"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "bidError").firstMatch.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText(XCUIKeyboardKey.delete.rawValue + "21100")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["reviewBid"].isHittable)
        app.buttons["reviewBid"].tap()
        XCTAssertTrue(app.buttons["confirmBid"].waitForExistence(timeout: 5))
        app.buttons["confirmBid"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "bidSuccess").firstMatch.waitForExistence(timeout: 5))
        app.buttons["dismissBidSuccess"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "currentBid").matching(NSPredicate(format: "label CONTAINS %@", "21,100")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["bidCount"].label, "12 bids")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved demo bid on iPhone"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "21,100")).firstMatch.exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "21,100")).firstMatch.exists)
        row.tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "currentBid").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(identifier: "currentBid").matching(NSPredicate(format: "label CONTAINS %@", "21,100")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["bidCount"].label, "12 bids")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["resetDemoBids"].tap()
        confirmResetDemoBids(in: app)
        let resetApplied = expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "21,000")).firstMatch)
        wait(for: [resetApplied], timeout: 5)
        row.tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "currentBid").firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["bidCount"].label, "11 bids")
    }


    @MainActor
    func testBidSheetRemainsReachableAtLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--offline-images"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("A-0001")
        let row = app.descendants(matching: .any).matching(identifier: "vehicle-A-0001").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let inventory = XCTAttachment(screenshot: app.screenshot())
        inventory.name = "Inventory text layout"
        inventory.lifetime = .keepAlways
        add(inventory)
        row.tap()
        let bidButton = app.buttons["placeBid"]
        XCTAssertTrue(bidButton.waitForExistence(timeout: 5))
        XCTAssertTrue(bidButton.isHittable)
        bidButton.tap()
        let amount = app.textFields["bidAmount"]
        reveal(amount, in: app)
        XCTAssertTrue(amount.isHittable)
        let sheet = XCTAttachment(screenshot: app.screenshot())
        sheet.name = "Bid sheet text layout"
        sheet.lifetime = .keepAlways
        add(sheet)
        app.navigationBars.buttons["Close"].tap()
        XCTAssertTrue(bidButton.waitForExistence(timeout: 5))
    }


    @MainActor
    private func confirmResetDemoBids(in app: XCUIApplication) {
        // The native confirmation can appear as an alert or action sheet.
        let alertButton = app.alerts.buttons["Reset demo bids"]
        if alertButton.waitForExistence(timeout: 3) {
            alertButton.tap()
        } else {
            let sheetButton = app.sheets.buttons["Reset demo bids"]
            XCTAssertTrue(sheetButton.waitForExistence(timeout: 3))
            sheetButton.tap()
        }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

}
