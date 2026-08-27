# Status

_Last updated: 2026-08-28_

## Build & test health

- Builds clean (Xcode MCP `BuildProject`, Debug configuration).
- `SlideshowTests` (`ContentViewModelTests`, Swift Testing): 17/17 passing.
- `SlideshowUITests`: skipped by the default test plan (unmodified Xcode boilerplate; drives real
  windows/focus and takes over the machine when run).

## What works today

- Full-screen slideshow of a folder's images: manual navigation, auto-advance, scroll-to-zoom,
  metadata overlay, in-app help overlay.
- Multiple windows, each independently loaded via the picker screen (folder or single-image
  selection, via panel or drag-and-drop) or Finder/Dock (folders only).
- Full multi-window state persistence: every open window's folder + selected image survives a
  complete quit/relaunch, restored to the picker screen (not auto-starting the slideshow).
- Finder/Dock folder opens land in a new window and clean up a redundant empty one if present.
- App-level Open (Cmd+O) / Continue (Cmd+R) / Re-start from Beginning (Cmd+Return) commands, correctly
  enabled/disabled based on the frontmost window's state.
- Settings window with live-updating `@AppStorage`-backed preferences shared with the running
  slideshow.

## Known gaps (tracked in Clarity, not yet started)

- No pinch-to-zoom or Cmd+/Cmd- shortcuts; no pan-while-zoomed.
- No menu-bar equivalents for in-slideshow toggles (Metadata/Auto Mode/Help/Reset Zoom); no Cmd-F
  full-screen toggle; no context menu/copy/share for the displayed image.
- No VoiceOver/accessibility support anywhere in the app.
- Memory footprint: every image in a folder loads eagerly into memory — untested at scale for very
  large folders.

## Repo state

- `main` is current (`b77c70a` as of this session); no other active branches.
- Working tree clean.
- No `.gitignore` in this repo — `.DS_Store`, `.claude/`, and Xcode user data are excluded via the
  user's global git config instead, not a project-local ignore file. Not a gap to fix unless that
  global config ever changes.
