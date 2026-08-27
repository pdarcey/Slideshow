# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Slideshow is a macOS app that displays a folder of photos/images full-screen, one at a time, with
user-configurable auto-advance timing, manual/auto progress, zoom, and metadata overlay. Multiple
windows are supported — each remembers its own folder and selected image across a full quit/relaunch.

It prioritises simplicity over "full-featuredness". It is there to display images as a slideshow; that's all!

- Bundle ID: `com.xerodonia.Slideshow`
- Deployment target: macOS 26/Tahoe
- Sandboxed app. Sandbox capabilities (`app-sandbox`, `files.user-selected.read-only`) are configured
  via Xcode's Signing & Capabilities UI as `ENABLE_APP_SANDBOX`/`ENABLE_USER_SELECTED_FILES` build
  settings rather than the raw `Slideshow.entitlements` file (which Xcode leaves as an empty `<dict/>`
  once a capability's been added this way — that's expected, not a sign anything's missing).

## Commands

There is no SwiftLint config or CLI tooling in this repo (no `Package.swift`, no `.swiftlint.yml`).
All building/testing goes through Xcode/`xcodebuild` on the `Slideshow.xcodeproj` project, scheme
`Slideshow`. The default test plan (`Slideshow.xctestplan`) skips `SlideshowUITests` — it drives real
windows/focus and takes over the machine on every run, and its only content is unmodified Xcode
boilerplate anyway.

```sh
# Build
xcodebuild -project Slideshow.xcodeproj -scheme Slideshow -configuration Debug build

# Run all tests (unit only, per the default test plan)
xcodebuild -project Slideshow.xcodeproj -scheme Slideshow test

# Run a single unit test
xcodebuild -project Slideshow.xcodeproj -scheme Slideshow test \
  -only-testing:SlideshowTests/ContentViewModelTests/freshViewModelStartsWithNotYetAttempted
```

Prefer the Xcode MCP server for builds/tests/adding files when it's available, per global
instructions. **Caution:** running tests through that server's `RunAllTests`/`RunSomeTests` has been
observed to silently rewrite `Slideshow.xctestplan` on disk (dropping a manually-disabled test
target, marking unrelated tests as skipped instead) — `git diff Slideshow.xctestplan` after a test
run and revert if it changed unexpectedly.

`SlideshowTests/ContentViewModelTests.swift` has real Swift Testing coverage (17 tests) for
`ContentView.ViewModel`'s loading/persistence logic, using real temp directories and real image
files rather than mocks. `SlideshowUITests` is still unmodified Xcode boilerplate.

## Architecture

State lives in one place — `ContentView.ViewModel` (in `ContentView+ViewModel.swift`) — with a small
coordinator, `AppCoordinator`, handling everything that's cross-window or app-lifecycle (multi-window
restore, Finder/Dock opens, closing a stale window). Each open `Slideshow` window is its own
`ContentView` instance with its own `ViewModel`.

- **`ContentView`** z-stacks `DefaultView` under `SlideView` (shown only once a slideshow is running).
  Its `.onAppear` does, in a deliberately fixed order (see the comment in the source — getting this
  wrong caused real bugs during Stage 5 development): capture this window and hand
  `AppCoordinator.shared.openWindowAction`, run `bootstrapLaunchIfNeeded` (launch-time restore),
  consume any pending restore for a freshly-opened window, wire `viewModel.onStateChanged`, then
  register the window with `AppCoordinator`. It also exposes the frontmost window's state/actions to
  app-level `.commands` via `.focusedSceneValue(\.slideshowWindow:)` (see `FocusedSlideshowWindow`).
- **`ContentView.ViewModel`** (`@Observable @MainActor`) owns `images: [Slide]`, `index`, and
  `emptyReason: EmptyReason` (`.notYetAttempted` / `.accessDenied` / `.noSupportedImages` /
  `.previousFolderUnavailable` — distinct user-facing explanations for why the picker screen is
  empty, rather than one generic message). `getImagesAtURL` loads every image in a folder *eagerly*
  into memory (no lazy/paged loading) and refreshes a security-scoped bookmark (`bookmarkData`) on
  every successful load; `resume(from:)` resolves a persisted `WindowState`'s bookmark and reuses the
  same `getImagesAtURL` pipeline. Fully unit-tested in isolation (`ContentViewModelTests.swift`) —
  it has no `AppCoordinator`/UI dependency; `onStateChanged` is an injected closure, not a direct
  reference, specifically so tests never trigger real persistence side effects.
- **`Slide`** (`Identifiable`, real `UUID` per slide) is the model `SlideView` renders — replaced an
  earlier `[String: Image]` dictionary that had no real SwiftUI identity, which was the root cause of
  both a rendering glitch (a stray vertical line during crossfades) and broken keyboard focus after
  any `.id()`-based fix attempt. The fix was giving the *image content* its own identity
  (`.id(slide.id)` + `.transition`) while keeping all focus/key-handling modifiers on `SlideView`'s
  *outer*, identity-stable `ZStack` — see `SlideView.swift`'s comments for why that split matters.
- **`DefaultView`** is a pure view now — no file I/O or state of its own beyond `dragOver`. It's the
  drop target for the whole picker screen (not just the button), and its `EmptyReason` switch is what
  surfaces the four states above. The "Select Folder or Image…" button and its `NSOpenPanel` message
  both call out that picking a single image (not just a folder) is supported.
- **`SlideView`** is the full-screen slideshow. Auto-advance via `Timer.publish` +
  `@AppStorage("autoModeInterval"/"autoMode")`; keyboard navigation via `onKeyPress`; scroll-to-zoom
  via `ScrollZoomView` (an `NSViewRepresentable` bridging `scrollWheel(with:)`, since SwiftUI has no
  native scroll-delta gesture); metadata overlay and in-slideshow help overlay; full-screen toggling
  via `NSApplication.shared.keyWindow`, captured once via `@Environment(\.appearsActive)` rather than
  `NSApplication.shared.windows.last` (which doesn't reliably target *this* window when multiple
  Slideshow windows are open).
- **`AppCoordinator`** (`@Observable @MainActor`, `.shared` singleton) is the one place that needs to
  reach across windows or bridge into non-View code (`AppDelegate`). It:
  - Tracks each registered window as a `(weak ViewModel, weak NSWindow)` pair.
  - Drives **launch-time multi-window restore**: `bootstrapLaunchIfNeeded` loads the persisted
    `[WindowState]` list, resumes the first entry directly into the already-appearing window (never
    creates a window only to close it again), and opens one more window per remaining entry via a
    `pendingOpens` queue each new window's `onAppear` consumes exactly once. Deliberately doesn't rely
    on SwiftUI/AppKit's own scene restoration — Apple's docs note that's gated behind the
    user-toggleable "close windows when quitting" system setting, which would make restore silently
    stop working depending on a checkbox outside this app's control.
  - Persists on every load and on window close (`windowStateDidChange`) — except during quit:
    `AppDelegate.applicationShouldTerminate` sets `isTerminating` *before* any window starts tearing
    down, so windows disappearing because the *app* is quitting don't each re-persist over an
    emptying registry and wipe the saved state (a real bug caught during Stage 5 testing).
  - `closeEmptyWindows(excluding:)`: SwiftUI's `WindowGroup` + `CFBundleDocumentTypes` always creates
    and shows a *new* window for a Finder/Dock file open — there's no hook that fires before it's
    already on screen, so a pre-existing empty window can't be silently reused. Instead, once the new
    window has loaded content, this closes any other window that's still empty. Net effect (no
    redundant empty window) is the same; it's achieved by tidying up the stale window instead of
    preventing the new one, since a create-then-close flash on the *new* window was explicitly ruled
    out.
- **`AppDelegate`** now only implements `applicationShouldTerminate(_:)` (see above).
  `application(_:open:)` is deliberately *not* implemented — confirmed via `OSLog` tracing (no
  `AppCoordinator` activity logged around a Dock-drop event) that it never fires; `ContentView`'s
  `.onOpenURL` is the real delivery path for Finder/Dock opens once `CFBundleDocumentTypes` is
  registered.
- **`WindowState`**/**`WindowStateStore`**: a `Codable` bookmark-plus-selected-image-name pair,
  persisted as JSON in `UserDefaults` (arrays of `Codable` structs aren't `@AppStorage`-compatible).
  Security-scoped access is only ever held for the duration of one `resume(from:)` call — `defer`
  right after `startAccessingSecurityScopedResource()` — because `getImagesAtURL` already loads
  everything eagerly; there's no persistent access to release later. Bookmarks transparently follow a
  renamed/moved/trashed folder (confirmed via testing — `isStale` triggers a refresh, already handled
  by `getImagesAtURL`'s unconditional bookmark refresh on every successful load); only once the
  folder is genuinely gone does resolution fail, surfaced as `.previousFolderUnavailable`.
- **`FocusedSlideshowWindow`**: `.commands` in `SlideshowApp` live outside the view hierarchy, so this
  is what `ContentView` publishes via `.focusedSceneValue` for the app-level Open/Continue/Re-start
  from Beginning commands (`Cmd+O`/`Cmd+R`/`Cmd+Return`) to read via `@FocusedValue`.
- **Finder/Dock integration**: `Info.plist`'s `CFBundleDocumentTypes` registers only `public.folder`
  (role Viewer) — deliberately *not* individual image UTTypes. Sandboxed apps only get file-level (not
  folder-level) access when Finder hands over a single file via Open With/double-click, with no way to
  request broader access afterwards, so supporting that would just produce an unexplainable empty
  window. Removing the image UTTypes makes macOS itself decline those routes (no Open With entry, no
  double-click default, Dock icon refuses a single-image drop) instead of the app half-supporting a
  dead end. Dropping a *folder* on the Dock icon still works.
- **Settings** (`SettingsView`, macOS Settings scene) and the slideshow's own runtime toggles share the
  *same* `@AppStorage` keys (`autoModeInterval`, `autoMode`, `showMetadata`, `slideTransition`,
  `transitionDuration`) — changing one updates the other live.
- **`AboutView`**/**`SettingsView`**/**`HelpView`** (the in-app help overlay, `?`) are each their own
  `Window` scene with `.thickMaterial` background, no title bar, `.restorationBehavior(.disabled)`,
  and `.windowResizability(.contentSize)`. The Help *menu* (`Cmd+Shift+?`) instead opens Apple Help
  Book content via `NSHelpManager` — two separate, deliberately non-duplicate help mechanisms.

### Concurrency note

Main-thread window operations are wrapped in `Task { @MainActor in ... }` rather than
`DispatchQueue.main.async` — follow that pattern for new code in `SlideView`/`ContentView`.

### Diagnostics

`ContentView.ViewModel` and `AppCoordinator` both log via `OSLog` (`Logger(subsystem:
"com.xerodonia.Slideshow", category: ...)`) at the key decision points in the restore/persistence
flow (bookmark resolution, what gets registered/persisted/consumed, and why). This was added to
diagnose two real ordering bugs during Stage 5 and was deliberately kept in place afterwards — this
window-lifecycle code is exactly the kind of thing worth being able to debug via Console.app without
re-adding logging first.
