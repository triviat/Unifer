# Unifer

Unifer is a macOS clipboard manager with a shelf-style interface inspired by apps like Paste: global hotkey, horizontal clip carousel, folders, search, image support, and quick paste back into the active app.

## Current Scope

- Primary focus: native macOS app
- Android folder exists as an early stub and is not the current priority
- Built with SwiftUI + AppKit, packaged as a Swift Package executable

## Features

- Global hotkey: `⌥⇧V`
- Floating bottom shelf UI
- Clipboard history with automatic capture
- Live search across clip content, titles, and source app
- Folder organization with rename and colors
- Drag and drop clips into folders
- Text, rich text, links, files, and image handling
- Double-click or `Return` to paste selected content back

## Requirements

- macOS 14+
- Xcode Command Line Tools or full Xcode
- Swift 5.9+ toolchain compatible with your installed macOS SDK

## Run in Development

```bash
cd /Users/a1111/code/Unifer
swift run Unifer
```

When the app launches:

- Look for the clipboard icon in the macOS menu bar
- Press `⌥⇧V` to open the shelf
- Grant Accessibility permission if paste simulation with `⌘V` is blocked

## Build a Real `.app`

Use the included build script:

```bash
cd /Users/a1111/code/Unifer
chmod +x scripts/build_app.sh
./scripts/build_app.sh release
```

This creates:

```bash
/Users/a1111/code/Unifer/dist/Unifer.app
```

Open it with:

```bash
open /Users/a1111/code/Unifer/dist/Unifer.app
```

or move ```Unifer.app``` to Application's folder

### Optional Build Metadata

You can override bundle metadata during build:

```bash
UNIFER_BUNDLE_ID=com.yourname.unifer \
UNIFER_VERSION=1.0.0 \
UNIFER_BUILD_NUMBER=1 \
./scripts/build_app.sh release
```

## Project Structure

```text
Sources/Unifer/
  App/          app bootstrap and state
  Database/     GRDB models and migrations
  Services/     clipboard watching, persistence, paste flow
  UI/           shelf, panel, previews, settings
docs/
  SYNC_PROTOCOL.md
scripts/
  build_app.sh
UniferAndroid/
  Android prototype / placeholder
```

## Troubleshooting

### `swift run` or `swift build` fails with SDK/toolchain errors

This usually means the installed Swift compiler and the active macOS SDK do not match.

Try:

```bash
xcode-select -p
swift --version
```

Then either:

- switch to the intended Xcode with `sudo xcode-select -s /Applications/Xcode.app`
- or update Command Line Tools / Xcode so the toolchain matches the SDK

### Paste does not happen in the target app

Unifer simulates `⌘V`, so macOS may require Accessibility permission.

Check:

- `System Settings` → `Privacy & Security` → `Accessibility`
- make sure your built `Unifer.app` is allowed

## GitHub Publishing

Before pushing public updates, review:

- `docs/PUBLISHING.md`

## Status

This repository is under active iteration. The macOS experience is the main workstream.
