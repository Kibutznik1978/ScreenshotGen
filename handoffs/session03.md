## Session Summary
- Date: 2026-03-03
- Branch: feat/folder-free-app (PR #2 open against main)
- Commits: cee40be, 1752ccc (pushed to origin)

## What Was Done
- Replaced "Select Project Folder" UX with Application Support-backed multi-project architecture
- Created `Project` model wrapping `GeneratorConfig` + metadata (name, createdAt, UUID)
- Created `ProjectStore` (@Observable) replacing old `ProjectState` — manages CRUD, auto-save (debounced), image import, generation
- Projects stored in `~/Library/Application Support/ScreenshotGen/projects/<uuid>/` with `project.json` + `RawScreenshots/`
- Added `ProjectListView` sidebar — create, rename (inline), delete (right-click context menu)
- Converted `ContentView` to three-column `NavigationSplitView` (projects | slots | editor)
- Added drag-and-drop image import on individual slots AND bulk drop on entire slot list area
- Bulk drop auto-assigns to first empty slot, creates new slots if all filled
- Added `imageRevision` counter pattern to force SwiftUI re-render when filesystem-based state changes
- Added `make run` Makefile target (builds .app bundle and launches)
- Removed "Save" button — auto-save replaces manual save
- Updated all views (EditorPanel, ImportView, SlotListView, BottomPanel, PreviewPanel) from ProjectState to ProjectStore
- Tested Xcode build workflow (`make xcodegen` → open project → Cmd+R)
- Design docs saved to `docs/plans/2026-03-03-folder-free-app-*.md`

## Current State
- App opens immediately with a default "My App" project and 3 template slots — no folder picker
- Multi-project sidebar works (create, rename, delete, switch)
- Drag-and-drop image import works with instant UI refresh
- Generation flow works (pick output folder → render → open in Finder)
- CLI (`swift run ScreenshotGen`) unchanged and working
- `make run` builds .app with icon and launches
- PR #2 open: https://github.com/Kibutznik1978/ScreenshotGen/pull/2
- No known bugs

## Next Steps
- Merge PR #2 to main
- Test Xcode build workflow with the new ProjectStore (no more sandbox permission errors expected since no folder picker on launch)
- Consider adding project export/import (for sharing or backup)
- iPad generation end-to-end testing
- Landscape iPad support
- App Store prep: code signing, privacy policy, app description

## Notes
- The `imageRevision` pattern (`let _ = store.imageRevision` in view bodies) is needed because `rawImageExists` and `thumbnail` read from the filesystem, which SwiftUI can't observe. Incrementing the counter after `importImage` forces dependent views to re-evaluate.
- `ProjectStore` uses ISO 8601 date encoding/decoding for `project.json` files
- The generator still expects `projectDir/RawScreenshots/` structure — Application Support folders match this layout so `ScreenshotGenCore` needed zero changes
- `createProject()` creates a project with 1 slot (not 3 like `defaultProject()`) to keep new projects lightweight
- Old `UserDefaults` key `ScreenshotGenUI.projectDir` is now dead; new key is `ScreenshotGenUI.selectedProjectId`
