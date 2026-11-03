# Add searchable vehicle inventory

A buyer can search the bundled 200-vehicle inventory by make, model, year, VIN, or lot, inspect title and CAD price summaries, and open the selected vehicle's overview. Empty search restores the original inventory; unmatched queries show recovery guidance and a clear-search action.

## Acceptance scope

Implementation plan milestone 2 (no separate requirement IDs exist). All inventory remains reachable. Search ignores case and excess whitespace, and matches every query word across the searchable identity. Native search clearing restores all 200 vehicles. Vehicle IDs preserve selection into the correct identity/dealership overview.

## Architecture and UI

`SearchVehicles` owns matching in Domain. The inventory view model owns the query and exposes filtered results. Views render state and use native split navigation; the overview contains no data-source access. Shared presentation components handle placeholder image loading/fallback, title badges, and CAD formatting. No dependencies were added.

Text uses native Dynamic Type styles and wraps. Rows switch to a vertical layout at accessibility sizes and combine descriptive text for VoiceOver. Status badges include text and symbols, and the VIN has an explicit accessibility label/value. User-facing SwiftUI literals are localizable; vehicle identity strings remain source data.

## Validation

Ten unit tests passed on iPhone 18 Pro, iOS 27.2. The UI journey verifies VIN lookup, result count, selected vehicle identity and VIN, back navigation, clearing, and no-results recovery. The complete UI journey passed on the final run. The initial test selector failures were corrected using the VIN’s explicit accessible value and the native search field’s observed Clear text control. The test expectations still verify exact identity, VIN, result counts, and recovery.

## Limits

The destination is a vehicle overview. Full photo gallery, condition/specification sections, and demo bidding belong to later milestones. Imagery is synthetic and may fall back to a local car illustration. Runtime VoiceOver and large-text interaction audits remain pending. This milestone is validated only on the iPhone simulator.

Independent review: no actionable findings; Approve. `git diff --check` passed. The historical iPhone inventory screenshot was removed during submission cleanup.

## Inspection follow-up

Added a swipeable gallery with previous/next controls, image count and placeholder disclosure; full condition report, all damage notes, title and grade; all supplied specifications; and dealership/location. The iPhone salvage inspection and inventory regression tests both pass. Independent review found no actionable defects and recommended Approve. The auction summary and offline bid-sheet acceptance remain part of the upcoming bidding integration.
