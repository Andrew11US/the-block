# Implementation status

Implementation follows the challenge's approved buyer journey and the outer `IMPLEMENTATION_PLAN.md`. No separate requirement IDs exist. All implementation commits belong to this Xcode project repository.

| Milestone | Result |
| --- | --- |
| Foundation and data | Complete: all 200 records, load/error states, boundaries, resource membership. |
| Searchable inventory | Complete: identity search, result counts, recovery, title/price/image summaries, selection. |
| Inspection | Complete: gallery, full specs/condition/damage/dealership, auction summary and reachable bid sheet. |
| Demo bids and persistence | Complete: review/confirmation, latest-state rules, saved overrides, shared updates, restore/reset. |
| Validation and polish | Current iPhone automated coverage and historical largest-text checks are recorded in validation.md. iPhone is the submission platform; runtime VoiceOver remains unverified. |
| Setup and walkthrough | App-local README and walkthrough prepared; clean-source build passed as recorded below. No push or external submission. |

## Validation scope

The submission targets iPhone only. Current feature validation uses Xcode 27.2 (27B52), iPhone 18 Pro simulator, and iOS 27.2. iPad and Mac Catalyst are not validated submission platforms.

The current automated suite contains 41 unit test functions across eight Swift Testing suites (one parameterized function has ten malformed-input cases), plus 11 XCTest UI tests. Coverage includes fixture decoding, search and combined filters, watchlist persistence, auction boundaries and timezone handling, bidding and recovery, and image-loader scheduling/cache/cancellation. UI tests include offline buyer journeys and normal-launch quick-filter regressions with remote images enabled. All 41 unit tests and all 11 UI tests have passing results across the November 3 full run and focused reruns after correcting stale UI-test selectors and keyboard handling. See [current validation details](validation.md) for the initial failures, run results, and limitations.

## Review evidence

Historical independent milestone reviews reported no actionable defects after corrections. The October 31 largest-accessibility-text check passed in dark mode; source audits covered system text styles, wrapping/scrolling, native controls, VIN accessibility values, and status labels. These historical checks do not establish a fresh visual or runtime VoiceOver review of every subsequent feature.

Historical inventory, saved-bid, and largest-text screenshots were removed during submission cleanup and are not included in the repository; no new November 3 screenshots are claimed. Later scrolling, layout-loop, cached-schedule, and image-loading investigations are recorded in [performance notes](scrolling-performance.md).

## Commits

- `b05cb72` — foundation and vehicle data layer.
- `e6cc7ed` — searchable inventory.
- `ef9b645` — inspection details and gallery.
- `daf2be3` — validated demo bids and local persistence.
- `ab230be` — final iPhone validation and accessibility layout polish.

No push, pull request, or external submission has been performed. The parent challenge repository now tracks the Xcode app directly, and its README links to the app instructions. The former nested repository metadata and history are preserved in a local backup under the parent Git directory; that backup is not part of the submission.

## Historical clean-source build

Exported committed snapshot `273dc1e` with `git archive` to a fresh directory without `.git`, `xcuserdata`, DerivedData, or the outer challenge repository. Built scheme `the-block-app` using Xcode 27.2 and the iPhone 18 Pro simulator destination, with a new DerivedData directory and `CODE_SIGNING_ALLOWED=NO`: **BUILD SUCCEEDED**. This verifies project/scheme discovery and bundled resource inclusion without personal Xcode state. The final record-only documentation update changes no app or test source.

That clean-source result applies to the recorded historical snapshot, not the current feature set. Current validation is recorded separately in validation.md. Runtime VoiceOver and physical-device performance remain follow-ups for the iPhone scope.
