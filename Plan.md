# Plan

## Completed stages

1. Initial app (dictionary-based image loading, basic slideshow) — pre-refactor baseline.
2. Window-targeting fix, settings window sizing, help overlay.
3. `Slide`/`ContentView.ViewModel` identity refactor — fixed a crossfade rendering glitch and broken
   keyboard focus by giving slides real `Identifiable` identity while keeping focus/key handling on
   an identity-stable outer view. Made the view model unit-testable in isolation.
4. Drag-and-drop (whole picker screen as drop target) + Finder/Dock file-open integration, narrowed to
   folders only (individual image opens are a sandbox dead end — see `CLAUDE.md`/`Journal.md`).
5. Multi-window state persistence:
   - 5a: security-scoped bookmark persistence core (`WindowState`, `WindowStateStore`,
     `ContentView.ViewModel.resume(from:)`).
   - 5b: explicit multi-window replay at launch (`AppCoordinator.bootstrapLaunchIfNeeded`), not
     reliant on SwiftUI/AppKit's own scene restoration.
   - 5c: close a stale empty window after a Finder/Dock open (the achievable version of "reuse an
     empty window" — see `Journal.md` for why the original approach wasn't possible).
   - 5d: Open/Continue/Re-start from Beginning keyboard shortcuts (`FocusedSlideshowWindow`).
   - 5e: discoverability polish for picking a single file to start on.

6. Ran `initialise-new-project` against the existing setup (scoped down to build tooling only, since
   docs/`.gitignore`/git history already predated the skill): SwiftLint as a build phase, automatic
   `CFBundleVersion` bump from `git rev-list --count main` (`Scripts/update-build-number.sh`, run as
   the *last* build phase — this target's `GENERATE_INFOPLIST_FILE = YES` means a first-phase script
   can't influence generation regardless of ordering).
7. Stage 6 (quick wins): fixed the About screen's focus-ring border (`.focusEffectDisabled()`) and the
   Help screen's Light Mode legibility (adaptive colors instead of hardcoded white/outline text). Also
   split `HelpView.swift`/`MetadataTextView.swift`/`ScrollZoomView.swift`/`Settings.swift` into
   one-view-per-file, added Dark/Light previews where it made sense, and brought the whole project to
   zero SwiftLint warnings under a new `.swiftlint.yml`.
8. Stage 7 (ready-screen polish): fixed the file panel's "Start Slideshow" prompt (it only selects,
   doesn't start) to "Select"; window title now shows folder name + image count
   (`ContentView.ViewModel.folderName`, new); removed the now-redundant text label above the hero
   image (and a vestigial unused `@SceneStorage` that only it read); hero image gets a rounded clip,
   border, and shadow; the three ready-screen buttons are circular icon buttons with tooltips
   (`.buttonBorderShape(.circle)`); "Select" is the accent-tinted default before a folder's loaded,
   "Start" after; default window size is 1500×1500 (replacing a `.windowIdealPlacement` that filled
   the whole display); ending a slideshow (`Esc` or reaching the last slide) now updates the hero
   image to the last-displayed slide via a new `SlideView.onEnd` callback and
   `ViewModel.selectSlide(at:)`, and persists that selection across a relaunch the same way every
   other selection change does.
9. Stage 8 (zoom & pan): scale clamped to 1×-5× everywhere (scroll, pinch, keyboard — previously
   unclamped); Cmd-+/Cmd- step-zoom by 25%, bare `=` still resets scale *and* pan to defaults;
   drag-to-pan via a new `offset` state, active only once zoomed (a no-op at 100%, so it never
   competes with tap-to-advance), clamped to an approximation of the zoomed image's bounds based on
   the visible container size. Pinch-to-zoom needed a real fix mid-stage: a `MagnifyGesture` attached
   directly to the image did nothing, because `ScrollZoomView`'s NSView already has to sit on top of
   the whole slide area for scroll-wheel capture, and was silently swallowing magnify events before
   they reached the SwiftUI gesture underneath. Fixed by extending that same NSView bridge — renamed
   `ScrollWheelDetector` → `ZoomGestureDetector` — to also override `magnify(with:)`, exactly like it
   already overrides `scrollWheel(with:)`, feeding both through the same `setScale` path.
10. Stage 9 (hero ↔ slide transition): used `matchedGeometryEffect` rather than the
    `matchedTransitionSource`/`.navigationTransition(.zoom)` API originally suggested — that one's
    built specifically for `NavigationStack` push/pop, which this app deliberately doesn't use
    (confirmed with Paul before implementing). Shared `@Namespace` lives on `ContentView`, passed to
    both `DefaultView` (hero image) and `SlideView` (current slide). Needed a real fix mid-stage: since
    every slide shares the same `matchedGeometryEffect` id, and `.id(slide.id)` gives each slide fresh
    view identity, ordinary slide-to-slide navigation was *also* being treated as a hero-morph moment
    (replacing the plain crossfade with random-looking grow/slide artifacts) — fixed with a new
    `isHeroTransitionSlide` flag on `SlideView`, true only for the slide shown when the show starts and
    (briefly) whichever slide is showing when it ends, false for every ordinary navigation in between
    (every other slide gets a unique per-slide id instead, an inert no-op). Also extracted a shared
    `advanceSlide()` helper, deduplicating three near-identical "advance or end" blocks.
11. Stage 10 (menu-bar & window integration):
    - Cmd-F toggles full screen for the frontmost window (`CommandGroup(after: .toolbar)`).
    - Metadata/Auto Mode/Help/Reset Zoom got menu equivalents in a new "Slideshow" menu section, using
      the same bare M/A/?/= shortcuts as before (confirmed with Paul — a menu shortcut is matched
      before a focused view's `onKeyPress`, so the old bare-key handlers in `SlideView` for these four
      became dead code and were removed). Required lifting `currentImage`/`showHelp`/`scale`/`offset`
      from `SlideView`'s local `@State` up to `ContentView` as `@Binding`s, since app-level `.commands`
      can't reach a child view's local state — `FocusedSlideshowWindow` gained `toggleHelp`/
      `resetZoom`/`copyImage` closures for this.
    - `Slide` gained a `url` field. Context menu (Copy Image/Reveal in Finder/Share) added to the
      displayed image; Cmd+C added via a plain command in the "Slideshow" menu rather than
      `CommandGroup(replacing: .pasteboard)` — that placement ties Cmd+C to the classic `copy(_:)`
      responder-chain selector, which nothing in this app implements, and it stayed disabled even with
      `.disabled(false)` set explicitly.
    - Two real fixes needed mid-stage: (1) right-click did nothing at first — `.contextMenu` resolves
      through classic `rightMouseDown`/`menu(for:)` hit-testing, unlike `.gesture()`/`.onTapGesture()`
      (which already worked fine sitting under `ZoomGestureDetector`'s overlay) — fixed with a
      `hitTest(_:)` override on that same NSView declining right-clicks outright, so AppKit's hit-test
      falls through to the context menu underneath. (2) Copy/Share both read the file's actual bytes,
      unlike Reveal in Finder (which just hands a path to Finder, a separate process) — and the
      security-scoped access `getImagesAtURL` used for the original eager load had long since closed
      by the time either was tried. Fixed with a new `ContentView.withFolderAccess(_:)`, re-resolving
      the folder's stored bookmark on demand (mirroring what `resume(from:)` already does at launch);
      Share additionally copies to the temp directory first, since the Share Sheet's lifetime is
      async/indeterminate — far longer than a synchronous re-scoped access window can cover.
    - A third, cosmetic fix: `ShareLink`'s automatic popover positioning placed the Share Sheet
      off-screen (and, being modal, stuck there) when the window was full-screen. Replaced with a
      plain button driving `NSSharingServicePicker` directly, anchored at the mouse pointer via a new
      `ShareSheetPresenter`.
12. Stage 11 (accessibility audit): ran the `swiftui-accessibility-auditor` skill across the whole app;
    findings graded P0-P2, all implemented.
    - P0: `SlideView`'s displayed photo is now the one VoiceOver-actionable element for the whole
      slideshow — labeled with filename + position, `.isButton` trait, default action = advance
      (matches tap-to-advance), plus "Previous Slide"/"End Slideshow" as VoiceOver rotor actions (a
      new `goToPreviousSlide()` was extracted alongside the existing `advanceSlide()` for this).
      `MetadataTextView`'s overlay and the invisible `ScrollZoomView` gesture layer are now
      `.accessibilityHidden` to avoid duplicate/empty announcements. `OutlineText` (nine overlapping
      copies of the same string, for its outline effect) now collapses to one accessibility element
      with one label, instead of announcing nine times.
    - P1: new `Animation+ReduceMotion.swift` (`withOptionalAnimation`, a drop-in `withAnimation`
      replacement) wired into every animated transition across `SlideView`/`DefaultView`/`ContentView`
      — slide crossfades, zoom, the hero morph, the drag-highlight — so Reduce Motion cuts instantly
      instead of animating. `DefaultView`'s hero image also gained a filename-based accessibility
      label.
    - P2: `AboutView`'s app icon marked `.accessibilityHidden(true)` (redundant with adjacent
      "Slideshow" text). `SettingsView`'s two sliders switched from an embedded-value label to a
      static label + `.accessibilityValue`.
    - Investigated a real platform limitation while verifying: the app doesn't appear in System
      Settings' per-app Text Size list (Accessibility → Display → Text Size). Confirmed via Apple
      Developer Forums (including a DTS engineer reply) this is a currently-curated allowlist of
      Apple's own apps only — no Info.plist key, entitlement, or API exists for a third-party app to
      register, regardless of correct semantic SwiftUI font usage (which this app already has). Not
      fixable from here; noted and dropped.
    - Confirmed live by Paul, including a real regression caught along the way: the Settings sliders'
      value text (e.g. "3.0 seconds") isn't visibly rendered by `Slider`'s label closure on macOS at
      all — Paul confirmed this is an acceptable, out-of-our-control platform quirk rather than
      something to chase further.

All merged to `main` as of 2026-08-28.

## Next stages: confirmed order

The remaining Clarity backlog (1 outstanding issue), grouped by what touches the same code and what
depends on what, confirmed with Paul 2026-08-28:

**Deferred, not part of this stage plan:** multiple selectable transition styles between slides
(fade/slide/flip/grow-shrink) — low priority, large scope on its own; revisit as a future stage.

### Stage 12: Memory footprint
- `ContentView.ViewModel.getImagesAtURL` loads every image in a folder eagerly into memory via
  `NSImage(contentsOfFile:)`. Fine for modest folders, potentially heavy for very large ones. Any fix
  here needs to reconcile with the security-scoped bookmark design in `resume(from:)`, which currently
  assumes access is only needed for the duration of the eager load (see `Journal.md`) — lazy/paged
  loading would change that assumption and need its own access-lifetime handling. Saved for last:
  backlog-priority, most architecturally invasive, benefits from not being rushed alongside UI work.

## Working rhythm (established over Stage 5)

- Plan a stage, confirm scope with Paul before starting.
- Work sub-stage by sub-stage: build + automated tests after each code change; where behaviour is only
  observable at runtime (window lifecycle, multi-window scenarios), ask Paul to manually verify before
  committing.
- Never commit until Paul has confirmed a fix actually works — a clean build/passing tests alone isn't
  sufficient sign-off.
- When a design assumption turns out wrong (e.g. the Finder/Dock delivery-path mix-up in Stage 5c),
  explain what was found and why, propose the revised approach, and get it confirmed before continuing
  — don't just silently change scope.
