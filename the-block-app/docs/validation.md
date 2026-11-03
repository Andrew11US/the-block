# iPhone validation — November 3, 2026

## Scope and environment

This submission targets **iPhone only**. Validation uses Xcode 27.2 (27B52), iPhone 18 Pro simulator, iOS 27.2, and Debug builds. iPad and Mac Catalyst are not validated submission platforms. Physical-device performance, runtime VoiceOver speech/gestures, translated strings, and poor-network behavior remain unverified.

The current run builds app source at `ab203df` with documentation updates and the UI-test selector corrections described below. No app behavior changed during this validation update.

## Automated coverage

- **41 Swift Testing unit test functions in eight suites**, including a parameterized function with ten malformed bid-input cases. The full unit suite passed on November 3.
- **11 XCTest UI tests** cover search/selection/clear; filter apply/cancel/reset; watchlist save/inspect/relaunch/remove; live/upcoming/ended status and bid availability; salvage inspection/gallery selection; bid cancellation, input validation, review/confirmation, shared state, persistence, and reset; bid-sheet reachability; scrolling measurements; and quick-filter selection/clearing with subsequent scrolling/watchlist access.
- Unit coverage includes all 200 fixture records, combined search/filter behavior, watchlist persistence, exact auction start/end boundaries, malformed schedules, timezone/daylight-saving handling, confirmation-time revalidation, bid/storage recovery, and update streams. Controlled URLSession tests cover bounded downloads, reserved selected-photo capacity, full-gallery preloading, coalescing, decoded-cache availability/reuse, and cancellation.
- Most UI tests disable remote images for deterministic buyer journeys. Two quick-filter tests use normal app launches with remote images enabled. These establish UI regressions, not remote-host throughput or a physical-device frame-rate improvement.

## Run results and corrections

The initial full run built successfully and passed all 41 unit tests and nine of 11 UI tests. Two UI assertions were stale after prior UI changes:

1. The reset confirmation was exposed as an alert; the test queried only sheets. The helper now waits for an alert button, with a sheet fallback.
2. The VIN view exposes `VIN · <VIN>` as its text label; the test expected a separate accessibility value. The assertion now checks the current label.

The search journey passed on its focused rerun. The bidding journey then exposed two more outdated automation assumptions: the amount and CAD suffix both inherited `currentBid`, and Review was not hittable with the number pad open. The test now selects the expected amount within the identified price elements and uses the keyboard toolbar's Done control before Review. A scrolling-only attempt did not resolve keyboard occlusion. The final bidding rerun passed, including invalid input, confirmation, shared price/count updates, relaunch restoration, and reset.

**Final aggregate: all 41 unit tests and all 11 UI tests have passing results across the full run and focused reruns.** The original full run remains a failed result bundle; no single all-green full-suite rerun is claimed. Only UI-test code changed after that full run.

## Accessibility and visual evidence

The October 31 focused bid-sheet test passed at the largest accessibility text size in dark appearance, and its screenshots were visually inspected. Original simulator settings were restored afterward. That is historical evidence; the November 3 run does not independently set an accessibility text size, despite the reachability test's name.

Historical screenshots of the inventory and bid sheet at the largest text size, and a saved bid, were removed during submission cleanup and are not included in the repository. New UI-test screenshots are retained as result-bundle attachments. No fresh manual screenshot review or runtime VoiceOver review is claimed here.

The README describes current accessibility behavior. Earlier source audits and independent milestone reviews are historical evidence, not a fresh audit of all subsequent UI changes.

## Reproduction and local evidence

Run the README's build/test commands with an installed iPhone simulator. This run used a fresh DerivedData directory at `/tmp/the-block-submission-build` and `CODE_SIGNING_ALLOWED=NO`.

- Full-run log: `/tmp/the-block-submission-validation-20261103.log`
- Full-run result bundle: `/tmp/the-block-submission-validation-20261103.xcresult`
- Focused-rerun log: `/tmp/the-block-submission-retest-20261103.log`
- Focused-rerun result bundle: `/tmp/the-block-submission-retest-20261103.xcresult` (search passed; bidding exposed the duplicate price selector)
- Intermediate bid logs/result bundles: `/tmp/the-block-submission-bid-retest-20261103.{log,xcresult}` and `/tmp/the-block-submission-bid-final-20261103.{log,xcresult}` (keyboard-occlusion failures)
- Passing final bid log: `/tmp/the-block-submission-bid-done-20261103.log`
- Passing final bid result bundle: `/tmp/the-block-submission-bid-done-20261103.xcresult`

These are local temporary artifacts, not committed repository files. The full run emitted Xcode debugger-metadata and simulator accessibility-class warnings, a native frame-dimension warning when focusing the bid amount, and image-decompression diagnostics during controlled image tests; those tests passed. No new quantitative device performance claim follows from this run. Earlier investigation details and their limits are in [scrolling performance notes](scrolling-performance.md).
