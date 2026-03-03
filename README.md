# ScreenshotGen

App Store screenshot generator. Takes raw simulator screenshots, wraps them in device frames with captions, and outputs App Store-ready PNGs.

All customization happens in a single `config.json` file — no Swift code editing needed.

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/YourUser/ScreenshotGen.git
cd ScreenshotGen

# 2. Copy the example config and edit it
cp config.example.json config.json

# 3. Take simulator screenshots and drop them into RawScreenshots/
#    (filenames must match the "rawImage" values in config.json)

# 4. Generate
swift run ScreenshotGen
```

Output goes to `Output/<device>/`, e.g.:
```
Output/
├── iphone-6.7/
│   ├── 01-screenshot.png   (1290x2796)
│   └── 02-screenshot.png
└── ipad-12.9/
    ├── 01-screenshot.png   (2048x2732)
    └── 02-screenshot.png
```

## Config Reference

```json
{
  "gradientTopColor": "#337AF5",
  "gradientBottomColor": "#245CCC",
  "textColor": "#FFFFFF",
  "supportTextOpacity": 0.8,
  "devices": ["iphone-6.7", "ipad-12.9"],
  "screenshots": [
    {
      "id": "01",
      "rawImage": "01-dashboard.png",
      "caption": "Your headline\nwith line breaks",
      "supportText": "A subtitle under the headline"
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `gradientTopColor` | Yes | Top gradient color (hex) |
| `gradientBottomColor` | Yes | Bottom gradient color (hex) |
| `textColor` | Yes | Caption and support text color (hex) |
| `supportTextOpacity` | No | Opacity for support text (default: 0.8) |
| `devices` | Yes | Array of device sizes to generate |
| `screenshots` | Yes | Array of screenshot entries |

### Screenshot Entry

| Field | Description |
|-------|-------------|
| `id` | Output filename prefix (e.g., "01" → "01-screenshot.png") |
| `rawImage` | Filename to look for in `RawScreenshots/` |
| `caption` | Bold headline text. Use `\n` for line breaks. |
| `supportText` | Smaller subtitle text below the caption |

### Supported Devices

| Key | Output Size | Description |
|-----|------------|-------------|
| `iphone-6.7` | 1290x2796 | iPhone 15/16 Pro Max (6.7") |
| `ipad-12.9` | 2048x2732 | iPad Pro 12.9" |

## Custom Config Path

```bash
swift run ScreenshotGen path/to/my-config.json
```

## UI App (ScreenshotGenUI)

A macOS SwiftUI app that wraps the generator so you don't need to manually rename screenshots or edit config.json by hand.

### Build & Run

```bash
swift build --product ScreenshotGenUI
# or run directly:
swift run ScreenshotGenUI
```

You can also open the package in Xcode (`open Package.swift`), select the **ScreenshotGenUI** scheme, and run.

### Features

- **Load config.json** — On launch, select your project folder (the one containing `config.json`, `RawScreenshots/`, and `Output/`). The app remembers the folder between launches.
- **Screenshot slots** — See all screenshot entries from config with status indicators (green = raw image present, red = missing) and thumbnails.
- **Import screenshots** — Select a folder of images. Auto-assign by creation date or manually assign per slot. Images are copied into `RawScreenshots/` with the correct filenames.
- **Edit captions & colors** — Edit caption, support text per slot. Edit gradient colors with native color pickers. Changes are saved back to `config.json`.
- **Generate** — Runs the generator and streams log output. Opens the `Output/` folder on completion.

## Architecture

The project has three targets:

| Target | Type | Description |
|--------|------|-------------|
| `ScreenshotGenCore` | Library | Shared types (Config, DeviceSpec, views) and generator logic |
| `ScreenshotGen` | CLI | Thin wrapper that calls ScreenshotGenCore |
| `ScreenshotGenUI` | macOS App | SwiftUI app that wraps the generator |

## Requirements

- macOS 14+
- Swift 5.10+
- No third-party dependencies
