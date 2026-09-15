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
13. Housekeeping: reorganised `Slideshow/`'s ~24 source files (previously flat) into
    `App`/`Views`/`Views/ViewModels`/`Models`/`Services`/`Extensions`, per CLAUDE.md's standard
    template. File moves only, no code changes — done via the Xcode MCP (`XcodeMakeDir`/`XcodeMV`) so
    `project.pbxproj` stayed in sync automatically; every file confirmed byte-identical (git recognized
    all 24 as clean renames). `Info.plist`/entitlements/`Assets.xcassets`/`Preview Content/` stay flat,
    matching the template's own placement of those as direct children rather than nested.

All merged to `main` as of 2026-08-29, and pushed to `origin/main`.

## Next stages: confirmed order

Today's session (2026-09-15) folds in two Clarity issues that weren't reflected in this plan yet — the
outstanding backlog is actually 4 issues, not the 1 previously listed here. Grouped by what touches the
same code and what depends on what, confirmed with Paul:

**Deferred, not part of this stage plan:** multiple selectable transition styles between slides
(fade/slide/flip/grow-shrink) — low priority, large scope on its own; revisit as a future stage.

### Stage 14: Enter-to-start (p533)
- `DefaultView`'s button row already branches between a prominent "Select Folder or Image…" button (no
  folder loaded) and a prominent "Start" button (folder loaded). Add `.keyboardShortcut(.defaultAction)`
  to whichever one is prominent in each branch, so Enter/Return triggers it — standard HIG default-button
  behaviour. No `@FocusState`/architecture change needed; nothing else on the picker screen competes for
  Return.

### Stage 15: Reduce memory footprint (p406)
- `ContentView.ViewModel.getImagesAtURL` loads every image in a folder eagerly into memory via
  `NSImage(contentsOfFile:)`, storing a decoded `Image` on every `Slide`. `Slide` will drop that eager
  `image` field and decode on demand instead, for whichever slide is actually about to be shown.
- A small, strictly bounded on-demand cache (current slide + one-slide prefetch for smooth crossfades —
  at most 2 decoded images at any time, regardless of folder size) sits on the per-window `ViewModel`, so
  memory use stops scaling with folder size entirely. Explicitly cleared (not just overwritten) the
  moment a new folder is loaded into an existing window, so switching folders never accumulates stale
  entries from the old one — confirmed with Paul this needed to be a deliberate design point, not an
  assumed side effect. Window close needs no extra teardown: `AppCoordinator` already tracks the
  `ViewModel` only `weak`, so the cache is freed by ARC along with everything else when a window closes.
- Needs a shared "resolve bookmark → start security-scoped access → do work → stop access" helper, since
  decoding now happens at arbitrary later moments rather than one eager batch — generalized out of
  `ContentView.withFolderAccess(_:)` (currently private, Copy/Share-only) so both lazy slide loading and
  Stage 16 can use it.
- Rework the 26 `ContentViewModelTests` that currently assert against eager-loaded `Slide.image`.
- Paul verifies actual memory behaviour on a large folder before this gets committed.

### Stage 16: Save user-selected folders for future access (p534)
- Not a picker/UX problem — `NSOpenPanel` always works regardless of prior grants, confirmed with Paul.
  The actual gap is the sandbox restriction already documented in `getImagesAtURL`: dropping a single
  *file* only grants access to that file, so enumerating its parent folder fails unless the app already
  has broader access — today "already has" only means "already has this session." Goal: also honour
  access granted in a *previous* session, specifically for drag-and-drop.
- New `GrantedFolderStore`, same persisted-bookmark shape as `WindowStateStore`, but recorded on every
  successful `getImagesAtURL` load (panel pick, drag, Dock/Finder open, or `resume(from:)`) and — the key
  difference from `WindowState` — never removed when a window closes.
- Stored with **highest-ancestor deduplication** (confirmed with Paul): adding a new grant skips it
  entirely if an existing entry already covers it (same folder, or an ancestor of it); if the new grant
  is itself an ancestor of existing entries, those now-redundant descendants are dropped in favour of the
  new, higher one. E.g. granting `~/Documents` then `~/Documents/Images` stores only `~/Documents`;
  granting unrelated `~/Images/2026/January` first, then later `~/Images`, collapses down to just
  `~/Images`. Containment is checked via resolved, standardized `pathComponents`, not raw bookmark bytes
  or string prefixes (which would wrongly match `~/Documents2` against `~/Documents`).
- The same resolution pass that checks containment also prunes any stored bookmark that fails to resolve
  (folder deleted, or access revoked via System Settings → Privacy & Security → Files and Folders) —
  self-cleaning, no UI needed anywhere for this feature; revocation stays entirely the OS's own UI, per
  Paul.
- In `getImagesAtURL`, when direct enumeration fails, fall back to trying each persisted granted-folder
  bookmark via Stage 15's shared access helper before giving up with `.accessDenied`.
- Needs one small testability seam (an injectable lookup closure, matching the existing `onStateChanged`
  pattern) so this stays unit-testable without touching real `UserDefaults`.

Order: 14 → 15 → 16 (16 depends on 15's shared access helper). Pause after each stage for Paul to verify
before moving to the next; nothing gets committed until he's confirmed it actually works.

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
