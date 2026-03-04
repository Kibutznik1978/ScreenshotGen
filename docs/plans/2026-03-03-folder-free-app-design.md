# Folder-Free App UX Design

**Date:** 2026-03-03
**Status:** Approved

## Problem

The app requires users to select a "project folder" containing `config.json` on launch. This is friction inherited from the CLI tool. When running sandboxed (Xcode), it also causes permission errors trying to auto-load a previously saved path.

## Design

### Data Storage

All app data in `~/Library/Application Support/ScreenshotGen/projects/`. Each project is a UUID folder:

```
<uuid>/
  project.json     — Project metadata + GeneratorConfig
  images/
    01-screenshot.png
    02-screenshot.png
```

Auto-saves on every change (debounced). No manual save step.

### Project Model

```swift
struct Project: Codable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var config: GeneratorConfig
}
```

`ProjectStore` manages CRUD: list, create, delete, load/save. Replaces `ProjectState`'s file-path logic.

### First Launch

Creates one default project ("My App") with 3 template slots, blue gradient (`#337AF5` / `#245CCC`), white text, and 4 default iPhone device sizes.

### UI Structure

- **Outer sidebar:** project list with names. "+" to create, right-click to rename/delete.
- **Inner sidebar:** slot list for selected project (existing `SlotListView`).
- **Detail:** editor panel (existing `EditorPanel`).
- **Removed:** "Select Project Folder" empty state, folder toolbar button.

### Image Import

Drag-and-drop images onto slots in the slot list. App copies the dropped image into `<project>/images/` with the slot's expected filename. No `RawScreenshots/` folder management.

### Generate Flow

Unchanged — click Generate, pick output folder via `NSOpenPanel`, screenshots rendered there. Only remaining folder picker.

### What Stays the Same

- `ScreenshotGenCore` library — untouched
- CLI tool — still works with project-folder approach
- `GeneratorConfig` struct — `Project` wraps it

## Decisions

- **Approach A (Application Support)** chosen over Document-based (B) and Core Data (C)
- Multiple projects with sidebar navigation
- Template with 3 slots on new project creation
- Drag-and-drop for image import
