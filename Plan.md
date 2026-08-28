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

All merged to `main` as of 2026-08-28.

## Next stages: confirmed order

The remaining Clarity backlog (19 outstanding issues), grouped by what touches the same code and what
depends on what, confirmed with Paul 2026-08-28:

### Stage 6: Quick wins (isolated bug fixes)
- Fix the thick grey border around the link in the About screen.
- Fix Help screen's unreadable text in Light Mode.

### Stage 7: Ready-screen polish (batch — all touch `DefaultView`/`ContentView`)
- Rename "Start Slideshow" button → "Select".
- Window title → folder name + image count.
- Remove the now-redundant title above the hero image.
- Clip hero photo to rounded rect + border/shadow.
- Three ready-screen buttons → circles with images/tooltips.
- Accent colour on the default button.
- Default window size → 1500×1500.
- On `Esc`, hero image becomes the last-displayed slide (resume point).

### Stage 8: Zoom & pan (`SlideView`, `ScrollZoomView`)
- Pinch-to-zoom (`MagnifyGesture`) + Cmd+/Cmd- keyboard shortcuts — extends the existing `scale` state
  already used by scroll-to-zoom.
- Drag-to-pan a zoomed image — needs a new `offset` state, reset alongside the existing `=` handler.

### Stage 9: Slideshow transition (hero ↔ first slide only)
- Hero image ↔ first slide transition via `matchedTransitionSource`/`navigationTransition`.
- **Deferred, not part of this stage plan:** multiple selectable transition styles between slides
  (fade/slide/flip/grow-shrink) — low priority, large scope on its own; revisit as a future stage.

### Stage 10: Menu-bar & window integration
- Cmd-F full-screen toggle.
- Menu equivalents for Metadata/Auto Mode/Help/Reset Zoom (needs lifting some `SlideView` local
  `@State` to focused values, via `FocusedSlideshowWindow`).
- Context menu / Copy / Reveal in Finder / Share for the displayed image.

### Stage 11: Accessibility audit
- No VoiceOver support anywhere in the app. Deliberately scheduled *after* Stages 8–10, since those
  add new interactive surfaces (gestures, menu commands, context menu) that should get accessibility
  support built in the first time rather than retrofitted twice. Run the
  `swiftui-accessibility-auditor` skill across the whole app here.

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
