## Session Summary
- Date: 2026-03-03
- Branch: main
- Commit: 0e9e0fd (pushed to origin)

## What Was Done
- Replaced `DeviceSpec` enum with a struct-based catalog covering all App Store screenshot sizes
- Added 10 iPhone specs across 4 display categories (6.9", 6.5", 6.3", 6.1")
- Added 8 iPad specs across 4 display categories (13"/12.9", 11", 10.5", 9.7")
- iPhone uses 3x rendering, iPad uses 2x rendering — `renderScale` property on `DeviceSpec` drives `PNGExporter`
- Both factories (`iPhone(...)` and `iPad(...)`) proportionally scale frame visuals from reference devices
- Replaced per-device switch statements in `ScreenshotView` with a single `scaleFactor` for proportional text/spacing
- Added device selector UI in `EditorPanel` with iPhone and iPad columns side-by-side, grouped by display size category
- Each checkbox shows resolution + representative device name (e.g. "1290x2796 iPhone 15 Pro Max")
- Added +/- buttons at bottom of `SlotListView` sidebar for adding/removing screenshot slots
- `addSlot()` auto-increments ID, sets default placeholder text, and selects the new slot
- Updated `config.example.json` with new device ID format (e.g. `iphone-1290x2796`)
- Added `config.json` to `.gitignore` (local working config, not for repo)
- Updated `Generator.swift` to use `.id` instead of `.rawValue`

## Current State
- App builds and runs cleanly (`swift build` succeeds)
- All 18 device specs (10 iPhone + 8 iPad) are defined and selectable in the UI
- Generation works for selected devices — output directories named by device ID
- Config save/load works with new device ID format
- No known bugs or blockers

## Next Steps
- Test iPad generation end-to-end (verify output pixel dimensions are exact)
- Consider adding landscape iPad support (current layout is portrait-only)
- The 9.7" category could optionally include @1x sizes (768x1024) for very old iPads
- May want "Select All" / "Deselect All" buttons per category or platform
- Could add drag-to-reorder for screenshot slots
- Preview panel showing the composed screenshot before generation would be useful

## Notes
- iPad canvas dimensions are large (e.g. 1032x1376pt for 13") — text and frame scale proportionally from iPhone reference, verified the math works out to same visual proportions
- `DisplayCategory` has `.iPhoneCategories` and `.iPadCategories` static properties for UI grouping, plus `.all` for the combined list
- The 2048x2732 iPad spec serves both 13" and 12.9" categories (merged into one "13\" / 12.9\" Display" category to avoid duplicate checkboxes)
- `ScreenshotGenUIApp.swift` was previously modified to set `NSApplication.setActivationPolicy(.regular)` for bare executable support — that change is included in this commit
