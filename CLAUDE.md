# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Slideshow is a macOS app that displays a folder of photos/images full-screen, one at a time, with
user-configurable auto-advance timing, manual/auto progress, zoom, and metadata overlay. Multiple
windows are supported — each remembers its own folder and selected image across a full quit/relaunch.

It prioritises **simplicity** over "full-featuredness". It is there to display images as a slideshow; that's all!

- Bundle ID: `com.xerodonia.Slideshow`
- Deployment target: macOS 15 (Sequoia)
- Sandboxed app. Sandbox capabilities (`app-sandbox`, `files.user-selected.read-only`) are configured
  via Xcode's Signing & Capabilities UI as `ENABLE_APP_SANDBOX`/`ENABLE_USER_SELECTED_FILES` build
  settings rather than the raw `Slideshow.entitlements` file (which Xcode leaves as an empty `<dict/>`
  once a capability's been added this way — that's expected, not a sign anything's missing).

## Commands

No `Package.swift`; building/testing goes through Xcode/`xcodebuild` on the `Slideshow.xcodeproj`
project, scheme `Slideshow`. The default test plan (`Slideshow.xctestplan`) skips `SlideshowUITests` —
it drives real windows/focus and takes over the machine on every run, and its only content is
unmodified Xcode boilerplate anyway.

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
instructions.

`SlideshowTests/ContentViewModelTests.swift` has real Swift Testing coverage (26 tests) for
`ContentView.ViewModel`'s loading/persistence logic, using real temp directories and real image
files rather than mocks. `SlideshowUITests` is still unmodified Xcode boilerplate.

**Build tooling** (added via `initialise-new-project`): a `SwiftLint` Run Script phase runs
immediately after Compile Sources — `.swiftlint.yml` at the repo root configures `line_length`
(120, ignoring function declarations/comments/interpolated strings/URLs) and `nesting: type_level: 2`
(the default of 1 flags `ContentView.ViewModel.EmptyReason`'s deliberate 2-level nesting). A separate
"Update Build Number" phase — the *last* build phase, calling `Scripts/update-build-number.sh` — sets
`CFBundleVersion` to `git rev-list --count main` on every build; it has to run last and patch the
already-generated Info.plist rather than run first, because `GENERATE_INFOPLIST_FILE = YES` on this
target means build settings (and hence `CURRENT_PROJECT_VERSION`) are fully resolved before any script
phase runs, regardless of ordering. `MARKETING_VERSION` stays manually managed, untouched by either.

## Architecture

State lives in one place — `ContentView.ViewModel` (in `ContentView+ViewModel.swift`) — with a small
coordinator, `AppCoordinator`, handling everything that's cross-window or app-lifecycle (multi-window
restore, Finder/Dock opens, closing a stale window). Each open `Slideshow` window is its own
`ContentView` instance with its own `ViewModel`.

`Slideshow/` is organised by role (`App/`, `Views/`, `Views/ViewModels/`, `Models/`, `Services/`,
`Extensions/`) — a Stage 11 housekeeping pass, file moves only, no code changes.
`Info.plist`/`Slideshow.entitlements`/`Assets.xcassets`/`Preview Content/` stay flat directly under
`Slideshow/`.

- **`ContentView`** z-stacks `DefaultView` under `SlideView` (shown only once a slideshow is running).
  Its `.onAppear` does, in a deliberately fixed order (see the comment in the source — getting this
  wrong caused real bugs during Stage 5 development): capture this window and hand
  `AppCoordinator.shared.openWindowAction`, run `bootstrapLaunchIfNeeded` (launch-time restore),
  consume any pending restore for a freshly-opened window, wire `viewModel.onStateChanged`, then
  register the window with `AppCoordinator`. It also exposes the frontmost window's state/actions to
  app-level `.commands` via `.focusedSceneValue(\.slideshowWindow:)` (see `FocusedSlideshowWindow`).
  Since Stage 10, `ContentView` also owns `currentImageIndex`/`showHelp`/`scale`/`offset` as
  `@State`, passed into `SlideView` as `@Binding`s (not local to `SlideView` any more) — app-level
  `.commands` live outside the view hierarchy and can't reach a child view's local state, so this had
  to move up to be reachable via `FocusedSlideshowWindow`. `ContentView` also owns the shared
  `@Namespace` driving the hero-image morph (see `SlideView` below), and
  `copyImage(_:)`/`shareableCopy(of:)`/`withFolderAccess(_:)` — Copy/Share both need to briefly
  re-open security-scoped access via the stored bookmark before reading a file's bytes, since
  `getImagesAtURL`'s own access window (see `WindowState`/`WindowStateStore` below) is long closed by
  the time a user gets around to copying or sharing.
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
  Also carries the slide's file `URL` (since Stage 10) for Copy/Reveal in Finder/Share.
- **`DefaultView`** is a pure view now — no file I/O or state of its own beyond `dragOver`. It's the
  drop target for the whole picker screen (not just the button), and its `EmptyReason` switch is what
  surfaces the four states above. The "Select Folder or Image…" button and its `NSOpenPanel` message
  both call out that picking a single image (not just a folder) is supported. Its hero image shares a
  `matchedGeometryEffect` id with `SlideView`'s current slide (via `ContentView`'s `@Namespace`), so
  starting/ending a slideshow morphs the photo between ready-screen and full-screen rather than
  cutting or crossfading.
- **`SlideView`** is the full-screen slideshow — by far the largest file in the project. Auto-advance
  via `Timer.publish` + `@AppStorage("autoModeInterval"/"autoMode")`; keyboard navigation via
  `onKeyPress`; metadata overlay and in-slideshow help overlay; full-screen toggling via
  `NSApplication.shared.keyWindow`, captured once via `@Environment(\.appearsActive)` rather than
  `NSApplication.shared.windows.last` (which doesn't reliably target *this* window when multiple
  Slideshow windows are open).
  - **Zoom & pan** (Stage 8): scroll-wheel, pinch, and Cmd-+/Cmd- keyboard shortcuts all feed one
    `setScale(_:)`, clamped to 1×–5×. Drag-to-pan is a no-op at 100% (nothing to pan, and it must never
    compete with tap-to-advance). Pan is clamped to an *approximation* of the zoomed image's bounds
    (based on the visible container size, not the actual per-photo aspect-fit dimensions — `Slide`
    doesn't carry native pixel size).
  - **The hero-morph scoping problem**: every slide shares `SlideView`'s `matchedGeometryEffect` id
    with the hero image *only* when `isHeroTransitionSlide` is true — set going into the very first
    slide shown and (briefly) whichever slide is showing when the show ends, false for every ordinary
    slide-to-slide navigation in between. Tagging *every* slide unconditionally (the first attempt)
    made ordinary navigation get treated as a hero-morph moment too, replacing the plain crossfade with
    random-looking grow/slide artifacts — `.id(slide.id)` giving each slide fresh identity is exactly
    what triggered it.
  - **Context menu & Cmd+C**: Copy Image/Reveal in Finder/Share… on the displayed image. Copy and
    Share both route back up through `ContentView`'s `withFolderAccess(_:)` (see above) rather than
    reading the file directly here. Share uses a bespoke `ShareSheetPresenter` (native
    `NSSharingServicePicker`, anchored at the mouse pointer) instead of `ShareLink` — `ShareLink`'s
    automatic popover positioning places the Share Sheet off-screen, and stuck there, when the window
    is full-screen.
  - **Accessibility**: the displayed image is the one VoiceOver-actionable element for the whole
    interaction — labeled with filename + position, `.isButton` trait, default action = advance
    (matches tap-to-advance), "Previous Slide"/"End Slideshow" as VoiceOver rotor actions.
    `MetadataTextView`'s overlay and the invisible `ScrollZoomView` gesture layer are
    `.accessibilityHidden` to avoid duplicate/empty announcements. Every animated transition here (and
    in `ContentView`/`DefaultView`) goes through `withOptionalAnimation` (`Extensions/
    Animation+ReduceMotion.swift`) instead of `withAnimation` directly, so Reduce Motion cuts instantly
    rather than animating.
- **`ScrollZoomView`/`ZoomGestureDetector`**: an `NSViewRepresentable`/`NSView` pair bridging three
  things SwiftUI's own gesture system doesn't reach here, all via raw `NSEvent` overrides —
  `scrollWheel(with:)`, `magnify(with:)` (pinch), and a `hitTest(_:)` override that declines
  right-clicks outright. All three exist because this view *has* to sit on top of the whole slide area
  to catch scroll/magnify events at all, which means it also silently swallows other event types
  nothing asked it to touch (a `MagnifyGesture`/`.contextMenu` attached directly to the image
  underneath did nothing, for exactly that reason, before each override was added) — see `Journal.md`
  ("The overlay that ate everything") for the full story. Plain SwiftUI `.gesture()`/`.onTapGesture()`
  (tap-to-advance, drag-to-pan) are *not* affected by the same overlay — they ride a different event
  path than the classic AppKit hit-testing `.contextMenu`/pinch both go through.
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
  everything eagerly; there's no persistent access to release later *for that purpose*. Stage 10's
  Copy/Share needed file access again, well after that window closed — see `ContentView
  .withFolderAccess(_:)` above, which re-resolves the same bookmark on demand rather than changing
  this original design. Bookmarks transparently follow a renamed/moved/trashed folder (confirmed via
  testing — `isStale` triggers a refresh, already handled by `getImagesAtURL`'s unconditional bookmark
  refresh on every successful load); only once the folder is genuinely gone does resolution fail,
  surfaced as `.previousFolderUnavailable`.
- **`FocusedSlideshowWindow`**: `.commands` in `SlideshowApp` live outside the view hierarchy, so this
  is what `ContentView` publishes via `.focusedSceneValue` for app-level commands to read via
  `@FocusedValue` — Open/Continue/Re-start from Beginning (`Cmd+O`/`Cmd+R`/`Cmd+Return`), plus (Stage
  10) `toggleHelp`/`resetZoom`/`copyImage` closures backing the "Slideshow" menu's Toggle Help
  Overlay/Reset Zoom/Copy Image commands. Note: `CommandGroup(replacing: .pasteboard)` looked like the
  obvious placement for Cmd+C, but it ties itself to the classic AppKit `copy(_:)` responder-chain
  selector — which nothing in this app implements — and stayed disabled no matter what; Copy lives as
  a plain command in the bespoke "Slideshow" `CommandMenu` instead, alongside the others.
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

Separately: live SourceKit diagnostics (the red squiggles an editor shows *before* a real build) lag
noticeably behind on-disk changes in this project, especially right after a file is moved or split —
"Cannot find type 'X' in scope" across half the project immediately after an ordinary edit has, every
time so far, turned out to be a stale index rather than a real error. Trust an actual
`xcodebuild`/Xcode-MCP build over live diagnostics here.
