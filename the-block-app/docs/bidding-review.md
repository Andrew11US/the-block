# Add validated demo bidding and persistence

A buyer can enter a CAD amount, review the vehicle and amount, confirm a simulated bid, and see the saved price and bid count in both detail and inventory. Cancellation and rejected bids leave state unchanged. Bids restore after relaunch; confirmed reset restores the supplied fixture.

## Acceptance scope

Implementation plan milestones 3–4; there are no separate requirement IDs. This completes the auction summary and bid-sheet integration deferred from inspection. The UI shows the current or starting bid, bid count, reserve status, minimum next bid, and simulation disclosure. It does not expose a purchase workflow or reserve threshold.

## Architecture

Domain owns bid state, parsing/minimum/reserve policy, repository contract, and PlaceBid/ResetDemoBids use cases. Data owns a versioned override envelope and atomic file writes. One MainActor repository serializes reading the latest state, validating, saving, and publishing. It publishes only after a successful write; failures preserve the prior state. Inventory and detail subscribe to its updates. Terminated observers remove their continuations through weak captures.

Presentation owns editing/review/success stages. Confirmation validates the latest repository state again, and the stage guard prevents repeated confirmation from creating extra bids. App constructs dependencies and selects a separate file when running UI tests.

## Policy and recovery

The first bid may equal the starting bid. Later bids require at least CAD 100 above the current bid. Inputs use whole-dollar ASCII digits, with optional surrounding whitespace. Fractional, signed, formatted, malformed, and overflowing input is rejected. Integer limits are checked before additions. Reserve status changes when the accepted amount crosses the supplied threshold, but the threshold is absent from buyer views.

Missing storage starts from the fixture. Corrupt or unsupported storage falls back without crashing and shows a recovery message. Save and reset failures are reported without claiming success. Reset requires explicit confirmation.

## Validation

The 21-test unit suite passed on iPhone 18 Pro, iOS 27.2. It includes ten malformed-input cases, bid boundaries, reserve crossing, isolated vehicle states, stale confirmation, duplicate confirmation, restore/reset/corruption, save failures, atomic file persistence, update streams, and integer overflow. UI tests verify the inventory and salvage inspection; the complete bid journey verifies cancellation, inline validation, submission, count increments, shared updates, relaunch restoration, and reset.

The UI suite uses a separate `ui-testing-demo-bids-v1.json` file; it does not reset manually entered demo bids. iPhone is the only validation destination for this milestone. Final UI result and independent review are recorded before commit.

Final result: the complete bid UI journey passed. Reset verification uses a bounded expectation for the restored CAD 21,000 row price, then checks the original 11 bids in detail; the store was independently inspected as an empty override envelope after reset. Search and salvage-inspection UI tests passed as well. Independent review: no actionable findings; Approve. `git diff --check` passed.

The historical saved-bid review screenshot was removed during submission cleanup.
