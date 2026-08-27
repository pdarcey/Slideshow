# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Slideshow is a macOS app that displays a folder of photos/images full-screen, one at a time, with
user-configurable auto-advance timing, manual/auto progress, zoom, and metadata overlay.

- Bundle ID: `com.xerodonia.Slideshow`
- Deployment target: macOS 15 (Xcode project setting; `Readme.md` states macOS 26/Tahoe as the
  intended requirement — treat macOS 26 as the design target per global instructions, but be aware
  the project file has not been bumped yet)
- Sandboxed app; entitlements only grant `com.apple.security.files.user-selected.read-only`

## Commands

There is no SwiftLint config or CLI tooling in this repo (no `Package.swift`, no `.swiftlint.yml`).
All building/testing goes through Xcode/`xcodebuild` on the `Slideshow.xcodeproj` project, scheme
`Slideshow`.

```sh
# Build
xcodebuild -project Slideshow.xcodeproj -scheme Slideshow -configuration Debug build

# Run all tests (unit + UI)
xcodebuild -project Slideshow.xcodeproj -scheme Slideshow test

# Run a single unit test
xcodebuild -project Slideshow.xcodeproj -scheme Slideshow test \
  -only-testing:SlideshowTests/SlideshowTests/testExample
```

Prefer the Xcode MCP server for builds/tests/adding files when it's available, per global instructions.
`SlideshowTests` and `SlideshowUITests` currently contain only the default Xcode-generated
boilerplate test methods — no real coverage exists yet.

## Architecture

The app is two screens wired together by a single piece of state in `ContentView`:

- **`ContentView`** owns `slideShowIsRunning`, the loaded `images` dictionary, and `startImageIndex`,
  and z-stacks `DefaultView` under `SlideView` (shown only once a slideshow is running and images
  are loaded).
- **`DefaultView`** is the picker screen: lets the user choose a file or folder (via `NSOpenPanel` or
  drag-and-drop), reads all supported images in that folder with `FileManager`, and populates the
  shared `images` dictionary and `startImageIndex` (the dropped/opened file, if any, becomes the
  starting slide). Supported extensions: jpg, jpeg, png, gif, bmp, tiff, heic.
- **`SlideView`** is the full-screen slideshow itself. Images are looked up by name from the
  `[String: Image]` dictionary, sorted alphabetically via a computed `imageNames` property (there is
  no separately-ordered array — sort order is always derived from the dictionary keys). It handles:
  - Auto-advance via a `Timer.publish` driven by `@AppStorage("autoModeInterval")` /
    `@AppStorage("autoMode")`
  - Keyboard navigation (arrows/space/return to advance, Esc to quit) via `onKeyPress`
  - Scroll-to-zoom via `ScrollZoomView`, an `NSViewRepresentable` wrapping an `NSView` subclass that
    intercepts `scrollWheel(with:)` — SwiftUI has no native scroll-delta gesture, so this bridges to
    AppKit
  - Metadata overlay (`MetadataTextView`, toggled with `M`) and an in-slideshow help overlay
    (`HelpView`, toggled with `?`)
  - Full-screen toggling directly on `NSApplication.shared.windows.last` (both entering, from
    `ContentView`'s `onAppear`, and exiting, from `SlideView`)
- **Settings** (`SettingsView`, macOS Settings scene) and the slideshow's own runtime toggles share
  the *same* `@AppStorage` keys (`autoModeInterval`, `autoMode`, `showMetadata`) — changing one
  updates the other live.
- **`AboutView`** is a custom About panel (replacing the default `CommandGroupPlacement.appInfo`
  command in `SlideshowApp`) shown in its own `Window` scene with `.thickMaterial` background and no
  title bar — `SettingsView` is wrapped the same way. Both use `.restorationBehavior(.disabled)` and
  `.windowResizability(.contentSize)` so they don't participate in window restoration and size to
  fit their content.
- Help menu (`Cmd+Shift+?`) opens Apple Help Book content (`NSHelpManager`) rather than the in-app
  `HelpView` overlay — these are two separate help mechanisms, not a duplicate.

### Dead code

`FileSystemReader.swift` and `ChatGPT.swift` are compiled into the app target but referenced by
nothing else in the codebase (`DefaultView` has its own inline duplicate of the file/folder-picking
and image-loading logic instead of using `FileSystemReader`). Don't assume either file is on any
live code path; check before extending them, and consider flagging removal/consolidation if you
touch this area.

### Concurrency note

Full-screen toggling and other main-thread window operations are wrapped in `Task { @MainActor in ... }`
rather than `DispatchQueue.main.async` — follow that pattern for new code in `SlideView`/`ContentView`.
`ChatGPT.swift` uses `DispatchQueue.main.asyncAfter` instead; that's inconsistent with the rest of the
codebase (and with global Swift concurrency instructions) — don't copy that pattern.
