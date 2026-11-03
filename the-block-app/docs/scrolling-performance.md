# Scrolling performance investigation — November 2, 2026

## Findings and changes

The inventory wrapped its entire List in a one-second TimelineView, rerunning search and filter logic on every tick. With an auction status filter selected, that path constructed a DateFormatter and parsed two timestamps for every candidate vehicle on every tick. Every inventory card also had a one-second timeline that rebuilt its heading, photo, specifications, price, bid button, and footer. The row and footer each parsed the schedule. The bid sheet similarly wrapped its whole scroll view in a one-second timeline.

Inventory filtering now updates on auction start/end transitions, with search results and parsed schedules prepared outside the timeline callback. Without a status filter, the list needs no scheduled auction updates or schedule preparation. Cards, the bid sheet, and the detail bid dock update at start/end boundaries. Only countdown footers retain one-second updates; their parsed schedule is reused across ticks. Ended and invalid auctions have no periodic footer timeline.

Schedule transition dates include an initial current-date entry followed by strictly future boundaries. Tests cover upcoming, exact start, and exact end so ended schedules do not replay past transitions or continue waking periodically.

## Measurements and validation

- An optimized standalone Swift benchmark compiled the actual Vehicle and AuctionSchedule source and constructed 200 schedules per pass for 100 passes. Total: 6.1988 seconds, approximately 62 ms per 200-vehicle pass on this Mac. This isolates parsing cost; it is not a frame-rate measurement. The old inventory incurs this full pass only when an auction status filter is selected, because its nil-filter condition short-circuits parsing.
- Final simulator build succeeded. All 35 unit tests in seven suites passed, including the added transition scheduling regression.
- Added an offline-image scrolling performance test using XCTOSSignpostMetric.scrollDecelerationMetric, three measured iterations of four fast swipes. It passed: duration samples 2.966583, 3.004409, 2.536537 seconds; mean 2.836 seconds, relative standard deviation 7.483%. Deceleration duration is a repeatability baseline, not FPS or a before/after improvement percentage.
- Simulator: iPhone 18 Pro, iOS 27.2; Xcode 27.2. Tests use Debug builds and disable network images to isolate view work.
- A 15-second Time Profiler recording was captured during the auction search/status journey, not the measured scroll journey. Instruments reported a missing input source warning; no quantitative CPU attribution is claimed from this trace.
- The first status UI run passed live/upcoming checks but failed its third search. Its accessibility snapshot showed query `C-0021iD-0031`, establishing stale search input. Status checks now launch independently to avoid the native toolbar clear-button automation issue. The rerun passed all live/upcoming/ended labels and bid-availability checks.

## Local evidence

Build log: `/tmp/the-block-perf-final-build.log`.
Unit test log: `/tmp/the-block-perf-test.log`.
Initial UI run including successful scrolling metrics: `/tmp/the-block-scroll-test.log`.
Status rerun log: `/tmp/the-block-status-retest.log`.
Instruments trace: `/tmp/the-block-scroll.trace` (contains the search/status journey).
Standalone parsing benchmark: `/tmp/block-schedule-bench.swift` and `/tmp/block-schedule-bench`.

No before/after hitch count, device energy measurement, or remote-image scrolling result has been established. A physical-device Release run with Animation Hitches and Power Profiler is needed to quantify the remaining frame drops and power consumption. Remote AsyncImage loading and the material photo-count badges remain separate possible contributors requiring measurement.

## Follow-up: quick filters

The first fix still constructed schedules for all candidate vehicles whenever a quick filter was selected. This caused another approximately 62 ms parsing burst on filter taps and any parent view reevaluation while a filter was active. Row construction also still parsed schedules.

VehicleDTO now parses the schedule once when creating each immutable Vehicle. AuctionSchedule(vehicle:) retrieves that stored value, so inventory quick filters, row creation, countdown footers, detail views, and bid policies all reuse the same validated dates. No global mutable cache or stale status is introduced: only the dates are cached, and status is still evaluated against the current clock.

An optimized benchmark over the actual 200-vehicle fixture compared 100 status-filter passes: reparsing took 6.200870417 seconds; cached dates took 0.000109 seconds, with identical live counts. This isolates schedule lookup and comparison and does not measure whole-screen rendering or FPS. Benchmark source: `/tmp/block-quick-filter-bench.swift`.

All 36 unit tests passed, including a check that every loaded vehicle's cached schedule matches parsing the source timestamps and timezone. Added a UI test cycling Upcoming → Ended → Live followed by fast scrolling. Unit-test and initial UI log: `/tmp/the-block-quick-filter-test.log`. The initial UI test lost the offscreen section header after fast swipes; the final test explicitly restores it between selections. The final filter-and-scroll test passed all three selections and scrolling. Final UI log: `/tmp/the-block-quick-filter-ui-retest.log`.

## Follow-up: minute-only countdowns

Countdown footers now display hours and minutes (for example, `20h 12m`) and refresh every 60 seconds instead of every second. Remaining time rounds up to the next minute. The parent start/end boundary timelines remain in place so auction status and bidding availability still change at the exact scheduled time. Ended/invalid schedules continue to have no periodic countdown.

## Confirmed freeze: List timeline layout loop

Reproduced the unresponsive screen in a normal simulator launch. The app process sustained 99.7% CPU. A five-second sample (`/tmp/block-filter-freeze.sample.txt`) captured the main thread in continuous SwiftUI/UIKit layout and AttributeGraph invalidation, including TimelineView update filters, rather than timestamp parsing.

The inventory List was inside a TimelineView whose schedule changed when selecting a quick filter. In addition, timeline origins throughout the views were freshly computed with Date.now during rendering. Keeping timeline origins stable eliminated the initial idle CPU loop (0.0% CPU in a subsequent ps snapshot), but the stronger UI test still reproduced a 100% CPU freeze when the List's filter and timeline schedule changed together.

The final implementation removes TimelineView around the inventory List. A cancellable view task updates the filter clock only at auction start/end boundaries. Search and quick-filter taps now update a normal List. Row, detail, bid-sheet, and footer timelines retain their origins in SwiftUI State so rerendering does not reset their schedules. Countdown updates remain once per minute. Existing cached auction dates are reused.

The normal-launch UI test (no offline or test launch flags) passed Upcoming → Ended → Live selection and scrolling. It checks actual selected traits and changed result counts, addressing the previous tests' weak label-only assertions. Log: `/tmp/block-filter-no-list-timeline-test.log`. Additional validation covers clearing a selected filter and opening/dismissing the watchlist afterward, plus the offline flow and unit tests. Final log: `/tmp/block-filter-final-regressions.log`. Both additional UI tests and all 36 unit tests passed.

CPU snapshots establish the reproduced busy loop and restored idle behavior, not physical-device power savings or measured frame-rate improvements.

## Detail countdown precision

The vehicle detail footer opts into an hours:minutes:seconds countdown with one-second updates confined to that footer. Inventory, watchlist, and bid-sheet footers retain minute-only countdowns. Timeline origins remain stable and the inventory List remains outside TimelineView.

## Visible image loading and detail priority

Replaced per-view AsyncImage requests with a shared URLSession image loader. Inventory/watchlist thumbnails subscribe only when they enter the scroll viewport; leaving it cancels their subscription. Requests without subscribers are removed from the queue or cancelled in flight. Identical URLs share one request, and decoded images use an NSCache with a 48 MB cost limit. Image decoding/display preparation runs on the session callback queue.

At most four downloads run together, with inventory limited to three so an opened detail or bid image has reserved capacity. Detail requests move ahead of queued inventory requests and use URLSession's high task priority; existing shared requests are promoted when a detail subscribes. The gallery requests only its selected page. The supplied extensionless placehold.co URLs request PNG, preserving their colours/query text and leaving fixture data unchanged.

Validation: simulator build succeeded; all 39 unit tests in eight suites passed, including three controlled URLSession tests for reserved capacity/concurrency limits, request coalescing/cache reuse, and queued/in-flight cancellation. The normal-launch quick-filter/scrolling UI test passed with remote images enabled. The gallery inspection test initially failed because its old selector expected static photo text rather than the current page buttons. Page buttons now expose their selected accessibility trait; the corrected selected-page check and the rest of the inspection journey passed on rerun. This UI journey uses offline images; it validates navigation, not remote download speed.

Logs: `/tmp/the-block-image-queue-tests.log`, `/tmp/the-block-image-queue-ui.log`, and `/tmp/the-block-image-gallery-retest.log`. These checks establish scheduling behavior and UI regressions, not a measured reduction in host response time or physical-device scrolling hitches.

## Full-gallery preloading — November 3, 2026

Opening details now preloads all gallery URLs, including pages that TabView has not instantiated. Background gallery requests outrank inventory; the selected photo/bid image has highest priority. Leaving the gallery cancels unfinished preload subscriptions. Identical requests still coalesce.

The shared loader now allows eight simultaneous downloads, up from four, with inventory limited to six and combined inventory/background gallery work limited to seven. Its URLSession also allows eight connections per host. The final slot remains available for a selected photo. These limits bound work; they do not guarantee the remote host will respond faster.

VehicleImage reads an already-decoded cache entry synchronously for its first render and preserves its loaded image when only priority changes. This removes the avoidable placeholder flash when switching to an already-loaded page. A photo that has not finished downloading still shows its loading state.

Validation: the gallery inspection/page-selection UI journey passed. All 41 unit tests in eight suites passed on the final source, including new full-gallery/cache-availability and selected-photo-capacity/cancellation checks. Initial preload tests exposed late URLSession callbacks contaminating counters after a previous test reset; each test now uses a unique host to isolate those callbacks. Logs: `/tmp/the-block-gallery-preload-tests.log` (initial tests and passing gallery UI journey) and `/tmp/the-block-gallery-preload-unit-retest.log` (passing final unit suite). No measured remote-host speedup is claimed.
