# Status

_Last updated: 2026-08-29_

## Build & test health

- Builds clean (Xcode MCP `BuildProject`, Debug configuration).
- `SlideshowTests` (`ContentViewModelTests`, Swift Testing): 26/26 passing.
- `SlideshowUITests`: skipped by the default test plan (unmodified Xcode boilerplate; drives real
  windows/focus and takes over the machine when run).
- SwiftLint runs on every build (added Stage 6); zero warnings across the project.
- `CFBundleVersion` bumps automatically from `git rev-list --count main` on every build.

## What works today

- Full-screen slideshow of a folder's images: manual navigation (arrow keys, space, tap-to-advance),
  auto-advance, metadata overlay, in-app help overlay.
- Zoom & pan: scroll-wheel, pinch-to-magnify, and Cmd-+/Cmd- keyboard shortcuts all feed one clamped
  (1×–5×) scale; drag-to-pan once zoomed, clamped to the visible container's bounds.
- A hero-image-to-slide morph transition (`matchedGeometryEffect`) when a slideshow starts/ends, on
  top of the ordinary crossfade/cut between slides.
- Full menu-bar integration: Cmd-F full-screen toggle, a "Slideshow" menu with Continue/Re-start plus
  Toggle Metadata/Auto Mode/Help Overlay/Reset Zoom (bare M/A/?/= shortcuts), Cmd+C to copy the
  displayed image, Cmd+O to open.
- Right-click context menu on the displayed image: Copy Image, Reveal in Finder, Share… (anchored at
  the mouse pointer, not the potentially off-screen default position).
- Accessibility: VoiceOver-actionable slideshow (labeled image, advance/previous/end actions), Reduce
  Motion respected throughout, no duplicate/decorative-element announcements.
- Multiple windows, each independently loaded via the picker screen (folder or single-image selection,
  via panel or drag-and-drop) or Finder/Dock (folders only).
- Full multi-window state persistence: every open window's folder + selected image survives a complete
  quit/relaunch, restored to the picker screen (not auto-starting the slideshow) — including wherever
  the user left off mid-slideshow (Esc or reaching the last slide updates and persists the selection).
- Finder/Dock folder opens land in a new window and clean up a redundant empty one if present.
- App-level Open (Cmd+O) / Continue (Cmd+R) / Re-start from Beginning (Cmd+Return) commands, correctly
  enabled/disabled based on the frontmost window's state.
- Settings window with live-updating `@AppStorage`-backed preferences shared with the running
  slideshow.
- Dynamic window title (folder name + image count) distinguishes multiple open windows; default window
  size 1500×1500.

## Known gaps (tracked in Clarity, not yet started)

- Memory footprint: every image in a folder loads eagerly into memory — untested at scale for very
  large folders (Stage 12, next up).
- Multiple selectable slide-transition styles (fade/slide/flip/grow-shrink) — deliberately deferred,
  low priority, large scope on its own.
- Not fixable from this codebase: the app can't appear in System Settings' per-app Text Size list
  (Accessibility → Display → Text Size) — confirmed via Apple Developer Forums (including a DTS
  engineer reply) that this is currently a curated allowlist of Apple's own apps only, with no
  third-party registration mechanism.

## Repo state

- `main` is current (`e7d49a9` as of this session, pushed to `origin/main`); no other active branches.
- Working tree clean.
- `Slideshow/` is organised into `App/`/`Views/`/`Views/ViewModels/`/`Models/`/`Services/`/
  `Extensions/` (Stage 11 housekeeping — file moves only, no code changes). `Info.plist`,
  `Slideshow.entitlements`, `Assets.xcassets`, and `Preview Content/` stay flat under `Slideshow/`,
  matching the team's standard template.
- No `.gitignore` in this repo — `.DS_Store`, `.claude/`, and Xcode user data are excluded via the
  user's global git config instead, not a project-local ignore file. Not a gap to fix unless that
  global config ever changes.
