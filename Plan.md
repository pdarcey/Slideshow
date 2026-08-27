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

All merged to `main` as of 2026-08-28.

## Next stage: pick one cluster

Four groupings remain in the Clarity backlog, not yet individually scoped the way Stage 5 was.
Suggested order given natural dependencies and effort:

### A. Zoom/pan
- Pinch-to-zoom (trackpad magnify gesture) and Cmd+/Cmd- keyboard shortcuts — `SlideView` already has
  scroll-to-zoom via `ScrollZoomView`; this extends the same `scale` state to more input methods.
- Drag-to-pan a zoomed image within the window — needs an offset alongside the existing `scale`.

### B. Menu-bar/window integration
- Menu equivalents for in-slideshow toggles (Metadata `M`, Auto Mode `A`, Help `?`, Reset Zoom `=`) —
  natural fit for `FocusedSlideshowWindow`, which already bridges frontmost-window state/actions to
  `.commands`; would need extending to also read/toggle `SlideView`'s local `@AppStorage`-backed state.
- Cmd-F to toggle full screen for the current window.
- Context menu / copy / share for the displayed image.

### C. Accessibility
- No VoiceOver support anywhere in the app. Not yet scoped — needs an audit pass first (which views,
  which controls, what the expected reading order/labels should be) before implementation.

### D. Performance — memory footprint
- `ContentView.ViewModel.getImagesAtURL` loads every image in a folder eagerly into memory via
  `NSImage(contentsOfFile:)`. Fine for modest folders, potentially heavy for very large ones. Any fix
  here needs to reconcile with the security-scoped bookmark design in `resume(from:)`, which currently
  assumes access is only needed for the duration of the eager load (see `Journal.md`) — lazy/paged
  loading would change that assumption and need its own access-lifetime handling.

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
