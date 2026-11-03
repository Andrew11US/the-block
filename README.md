# The Block app

A native SwiftUI buyer prototype for the supplied 200-vehicle inventory. Browse, search, and save vehicles to a watchlist, inspect specifications and condition, and place a simulated bid that updates inventory and detail and survives relaunch. No account, backend, or package installation is required.

## Time spent

Approximately 30 minutes went into planning and initial setup, one hour into the foundation, and two hours into new features and polishing. The remaining time went into UI polishing; that additional time was not separately quantified. The work extended beyond the suggested 3–4 hour timebox.

I started with the architecture and foundation, then covered the core functionality with unit tests to guard against regressions in later updates. With that base in place, I added extra features and refined the bidding flow. The remaining time went into polishing the UI.

## Platform scope

This submission targets iPhone. Current validation covers the iPhone 18 Pro simulator on iOS 27.2 only. iPad and Mac Catalyst are not validated submission platforms.

The scope is the buyer journey: browsing and searching inventory, inspecting vehicles, saving a watchlist, and placing simulated bids. Authentication, seller workflows, checkout, payments, and dealer administration are intentionally omitted. Inventory is bundled and bidding is local to this device.

## Stack

- **Frontend:** Swift and SwiftUI, using observable view models and native iOS controls.
- **Backend:** None. Repository implementations read bundled inventory and manage simulated bids locally.
- **Database:** No database engine. Inventory comes from bundled JSON, bid overrides are saved to a versioned JSON file, and watchlist selections use UserDefaults.
- **Testing:** Swift Testing for unit tests and XCTest for UI journeys.

## Run locally

Open `the-block-app/the-block-app.xcodeproj` in **Xcode 27.2 (27B52)**. Select the `the-block-app` scheme, choose an **iPhone running iOS 27.2**, and Run. The app and test deployment target is iOS 27.2. Physical devices require selecting your own development team in Signing & Capabilities.

The project uses Xcode's `project.xcproj` representation; retain that file. Both the Swift source and bundled `the-block-app/the-block-app/Resources/vehicles.json` are included in this repository. No external data generator is needed to build this app.

From the repository root:

```sh
xcodebuild -project the-block-app/the-block-app.xcodeproj -scheme the-block-app \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/the-block-build CODE_SIGNING_ALLOWED=NO build

xcodebuild -project the-block-app/the-block-app.xcodeproj -scheme the-block-app \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/the-block-build CODE_SIGNING_ALLOWED=NO \
  -only-testing:the-block-appTests -only-testing:the-block-appUITests test
```

Use an installed iPhone simulator name or its identifier if yours differs. The current implementation is validated on iPhone 18 Pro, iOS 27.2. Per project direction, current validation uses iPhone only. Mac Catalyst remains enabled, but its current feature build/layout and current iPad behavior have not been validated. An earlier foundation-only Catalyst build is historical evidence, not full desktop coverage.

## Buyer behavior and assumptions

- Search checks make, model, year, VIN, and lot. Every whitespace-separated word must appear in the searchable identity; case and word order do not matter. The filter button to the left of native search in the bottom toolbar opens make, body style, fuel type, title status, province, minimum year, and maximum mileage options. Tap Apply to update results; Cancel or swipe to dismiss discards edits. Reset filters immediately clears all applied filters and closes the sheet. Search and filters combine, preserving the original fixture order.
- Tap a vehicle row’s heart to add or remove it from the watchlist. The toolbar heart opens all saved vehicles, independently of search and filters, with access to vehicle details. Selections persist on this device across relaunches. Removing the last vehicle shows an empty state.
- Prices are CAD whole dollars. The first bid may equal the starting bid. Subsequent bids must be at least the current bid plus CAD 100. This increment is a documented prototype decision. Enter digits without currency symbols or separators; fractional, negative, malformed, and overflowing amounts are rejected.
- Review shows the vehicle and amount before explicit confirmation. Success means a simulated bid was saved on this device. It does not contact a dealership, purchase a vehicle, or declare a winner.
- Reserve status is “No reserve,” “Reserve not met,” or “Reserve met.” The threshold is omitted from buyer views. Buy-now values remain in the data model; there is no purchase action.
- Demo auction schedules use start/end timestamps in the supplied `auction_timezone` (currently America/Toronto). Cards and detail screens show upcoming, live, or ended status with countdowns. Bidding opens at the exact start and closes at the exact end; review and confirmation validate the current schedule. Green footers identify live auctions, blue identifies upcoming auctions, and red identifies ended auctions. These remain local simulations; the device clock controls timing. Lots A-0001 through A-0020 remain live until November 6, 2026 (18:00–19:35 America/Toronto), allowing testing over the next few days. Upcoming lots C-0021 through D-0030 start November 6–9 and end November 7–10, 2026, preserving their original durations. The static November 2026 schedules will need refreshing for later demos.
- Supplied image URLs are placeholders. The image loader requests PNG from placehold.co when no format is specified, because its default SVG response is unsupported by the native image decoder. A shared loader starts inventory requests only when images enter the scroll viewport, cancels unused work, coalesces identical URLs, and caches decoded images in memory (48 MB cost limit). Up to eight downloads run at once (including up to six inventory downloads), with capacity reserved for gallery and higher-priority selected detail/bid images. Opening details preloads every gallery photo; the selected page has highest priority. Cached photos display immediately without clearing when page priority changes. Unfinished gallery preloads cancel when the gallery closes. Images fall back to a local car illustration on failure. Images do not gate browsing, inspection, or bidding. Damage notes and title status are shown without implying that missing notes mean no damage.

## Architecture

The app uses logical Clean Architecture boundaries:

- **Domain:** plain vehicle/bid entities, search and bid policies, repository contracts, and LoadInventory/PlaceBid/ResetDemoBids use cases. No SwiftUI or concrete persistence dependency.
- **Data:** JSON DTO mapping, bundled resource access, and a versioned bid-override file. Vehicle identities and specifications retain the original challenge values; demo auction schedules include start/end timestamps and an explicit timezone. Do not regenerate vehicle IDs.
- **Presentation:** main-actor observable view models and small feature/shared SwiftUI components. Views render state and send actions; they do not decode JSON, access the bid file, or validate bids.
- **App:** constructs concrete repositories and injects use cases and repository contracts. One bid repository instance is shared across inventory, detail, and bid forms; no global singleton is used.

File reads for inventory run off the main actor; the small 200-record decode runs on the caller. Bid mutations run synchronously on the main actor, serializing latest-state validation, atomic file save, and update publication. Subscribers receive committed snapshots through AsyncStream; cancelled observers release their continuation. Presentation copies are display state, not an alternative authority.

## Persistence and reset

Only versioned per-vehicle overrides are saved under the app sandbox's Application Support directory, in `TheBlock/demo-bids-v1.json`. The bundled inventory is unchanged. Saved bids restore at launch. Invalid storage falls back to the fixture with a recovery message; failed saves/resets report failure and leave the prior state intact.

Use the inventory's **Reset demo bids** action, then confirm, to restore supplied prices and counts. Reset affects only this device's demo data.

UI tests launch with `--ui-testing` and use a separate `ui-testing-demo-bids-v1.json` file. They also use `--offline-images`, which disables remote vehicle image requests through a presentation environment value and exercises the local fallback. Normal runs load remote placeholders. These arguments do not alter bid rules.

## Testing and accessibility

The automated suite covers complete fixture decoding, search normalization and recovery, presentation loading/retry, bid boundaries and malformed input, reserve crossing, independent vehicles, stale/duplicate confirmation, integer overflow, file persistence, corrupt/unsupported storage, failed writes/resets, and update streams. Image-loader tests use a controlled URLSession protocol to verify concurrency limits, reserved detail capacity, full-gallery preloading, immediate cache access, duplicate-request sharing, decoded-cache reuse, and cancellation without contacting the image host.

The UI journeys cover searching/selecting/clearing; filter apply/cancel/reset; watchlist save, inspection, persistence, and removal; auction status and bid availability; quick-filter selection/clearing and scrolling; salvage condition and gallery inspection; bid cancellation, invalid input, review/confirmation, shared visible state, relaunch restoration, and reset; and reaching the bid sheet/input. Most journeys run with remote images disabled; two quick-filter regressions use normal launches with remote images enabled. Actual results and review evidence are recorded in [implementation status](the-block-app/docs/implementation-status.md), [inventory review](the-block-app/docs/inventory-review.md), and [bidding review](the-block-app/docs/bidding-review.md).

Views use system text styles, scrolling, wrapping text, native controls, and a vertical inventory layout at accessibility text sizes. VoiceOver rows combine descriptive text; the VIN is displayed with a VIN label; status badges include words and symbols. User-facing SwiftUI literals and error messages are localizable and numbers use locale-aware formatting. English is currently the only supplied language. Runtime VoiceOver interaction remains a manual review item.

## Walkthrough

1. Search `CG2UAF4T8LRBBVWJY` or `2025 Mazda CX-5`; open lot A-0001.
2. Inspect photos, specifications, condition, and dealership. Search `FCDBJZZV9APMK4UG8` for a salvage example with multiple damage notes.
3. Open Place demo bid, cancel once, then enter an amount below the minimum to see validation. Correct it, review, and confirm.
4. See the new price/count in detail and inventory. Relaunch to demonstrate restoration.
5. Return to inventory and reset demo bids for a repeatable demonstration.

## What I'd Do With More Time

I'd focus on helping buyers find suitable vehicles faster, inspect them more closely, and follow their auctions:

- **Image loading:** Further refine the existing image-loading queue so currently visible inventory cells load first, and tune prefetching and cancellation for fast scrolling and slower connections.
- **Sorting and filters:** Add sorting by auction end time, price, mileage, and year, along with more precise filters to narrow the inventory.
- **Saved searches:** Let buyers save their search and filter preferences and restore them in one tap.
- **Outbid notifications:** Add push notifications when another buyer beats the user's bid, backed by authoritative auction updates.
- **Full-screen gallery:** Let buyers open photos full screen and zoom in to inspect details.
- **3D and AR damage inspection:** Explore a 3D vehicle walkthrough with an AR viewing option and damage annotations, using captured inspection imagery and suitable 3D assets to help buyers understand damage before deciding to bid.
- **Auction reminders:** Let buyers opt into push reminders before an auction ends and open the relevant lot when they tap the notification.
- **Lot comparison:** Let buyers compare two or more similar lots side by side, including price, mileage, specifications, condition, and auction timing.

## Tradeoffs and next steps

The implementation prioritizes a repeatable buyer demo within the challenge scope. Compared with a production auction app:

- **Bundled inventory:** All 200 vehicles load without a backend, simplifying setup and keeping browsing reliable. Production would need an inventory API, refresh behavior, caching, and pagination.
- **Local bidding:** Latest-state validation, atomic saves, and shared screen updates make the demo consistent on one device. Production needs server-authoritative acceptance, competing-buyer concurrency, idempotent requests, and live updates.
- **Reserve confidentiality:** Buyer views hide reserve thresholds, but those values remain in the bundled JSON. Production should keep confidential thresholds on the server and return only reserve status.
- **Demo auction timing:** Fixed schedules and the device clock make auction states easy to demonstrate. They eventually become stale and are affected by clock changes; production needs authoritative server timing and auction lifecycle management.
- **No accounts:** Skipping authentication removes onboarding friction. Production needs buyer identity, authorization, eligibility checks, and account-based state across devices.
- **Simple persistence:** Versioned JSON bid overrides and UserDefaults watchlists preserve local state with little infrastructure. Production needs durable backend records, a bid audit trail, and synchronization/reconciliation policies.
- **Main-actor bid writes:** Synchronous writes serialize validation, persistence, and publication simply. Larger state or slower storage could block the UI; production should move I/O off the UI actor while preserving mutation ordering.
- **Small-dataset search:** In-memory token matching and filters are sufficient for 200 vehicles. Larger inventories need indexed search, relevance ranking, pagination, and user-controlled sorting.
- **Placeholder images:** A bounded, visibility-aware loading queue, memory cache, and local fallback keep the core journey usable. Production still needs real inspection photos, thumbnail sizing, deliberate disk-cache policy, and retry behavior.
- **Simplified auction rules:** Whole-dollar CAD amounts and a fixed $100 increment keep bidding understandable and testable. Bid history, proxy bidding, buy-now execution, checkout, payments, and seller tools are deferred.
- **Logical architecture boundaries:** Repository protocols, use cases, and view models support testing without separate package overhead. Boundaries are convention-based within one app target; separate modules could enforce them as the team and codebase grow.
- **Focused validation:** Current feature validation targets an iPhone simulator. iPad/Catalyst behavior, physical-device performance, runtime VoiceOver interaction, and translated languages need broader coverage; the iOS 27.2 deployment target also limits compatibility.
- **Targeted performance work:** Cached schedules and isolated countdown updates address observed costs, and the inventory layout-loop fix addresses a reproduced freeze. Simulator checks do not establish physical-device frame rates, energy use, or poor-network behavior.

The highest production priorities are authoritative bidding and timing, authenticated buyers, and keeping confidential auction data off the client, followed by real photographs and broader platform/accessibility validation.

AI assisted with architecture, implementation, test preparation, documentation, and independent code review. The supplied fixture and challenge scope guided product decisions. Build/test evidence and inspected screenshots are recorded rather than treating generated code as verified by default. The developer should review the code and runtime behavior before the final walkthrough. No repository has been pushed or sent to OPENLANE by this work.
