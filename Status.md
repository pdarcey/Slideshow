# Status

_Last updated: 2026-09-16_

## Build & test health

- Builds clean (Xcode MCP `BuildProject`, Debug configuration).
- `SlideshowTests` (`ContentViewModelTests` + `GrantedFolderStoreTests`, Swift Testing): 36/36 passing.
- `SlideshowUITests`: skipped by the default test plan (unmodified Xcode boilerplate; drives real
  windows/focus and takes over the machine when run).
- SwiftLint runs on every build (added Stage 6); zero warnings across the project.
- `CFBundleVersion` bumps automatically from `git rev-list --count main` on every build. `MARKETING_VERSION`
  is now `1.1.0` (bumped deliberately by Paul, Stage 17).

## What works today

- Full-screen slideshow of a folder's images: manual navigation (arrow keys, space, tap-to-advance),
  auto-advance, metadata overlay, in-app help overlay.
- Enter/Return starts the slideshow from the picker screen — triggers whichever of "Select Folder or
  Image…"/"Start" is currently the prominent default action (Stage 14).
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
  via panel or drag-and-drop) or Finder/Dock (folders only). The panel correctly allows selecting a
  folder directly again as of this session (a pre-existing `NSOpenPanel.allowedContentTypes` gap —
  missing `.folder` — meant only images were actually selectable; fixed alongside Stage 16).
- Images decode on demand rather than all up front — memory use stays flat regardless of folder size
  (a bounded 2-image cache, cleared whenever a window loads a new folder) rather than scaling with
  photo count. Confirmed by Paul on a real large folder: low 100s of MB, not gigabytes (Stage 15).
- Full multi-window state persistence: every open window's folder + selected image survives a complete
  quit/relaunch, restored to the picker screen (not auto-starting the slideshow) — including wherever
  the user left off mid-slideshow (Esc or reaching the last slide updates and persists the selection).
- Every folder ever granted access — not just currently-open windows' folders — is remembered
  indefinitely (deduplicated to the highest granted ancestor), so dragging a single *file* into an
  existing window works even when its parent folder was only ever granted in a previous session
  (Stage 16), *including* when the granted folder is purely organizational (contains only subfolders,
  none of which have images directly inside the top-level folder itself) — fixed in Stage 17 (p370)
  after Paul traced the original Stage 16 fallback to a real gap in exactly that scenario. Confirmed by
  Paul on both his main machine and a real macOS 15.7.9 machine.
- Cursor auto-hides after a couple of idle seconds while a slideshow is full-screen, and reveals again
  on movement or full-screen exit (Stage 17, p369) — tracks real `NSWindow` full-screen state, so it
  behaves correctly whether full-screen was entered via starting a slideshow or exited independently via
  Cmd-F.
- Right-click (or Cmd-click) the window's title text for the standard macOS folder-path popup — each
  folder in the path (and the selected image, if one was picked) opens in Finder (Stage 17, p372).
- Finder/Dock folder opens land in a new window and clean up a redundant empty one if present.
- App-level Open (Cmd+O) / Continue (Cmd+R) / Re-start from Beginning (Cmd+Return) commands, correctly
  enabled/disabled based on the frontmost window's state.
- Settings window with live-updating `@AppStorage`-backed preferences shared with the running
  slideshow.
- Dynamic window title (folder name + image count) distinguishes multiple open windows; default window
  size 1500×1500.

## Known gaps (tracked in Clarity, not yet started)

- Multiple selectable slide-transition styles (fade/slide/flip/grow-shrink, `p292`) — deliberately
  deferred, low priority, large scope on its own. As of Stage 17, this is the *only* item left in
  Clarity's backlog for this project — every other tracked issue is Completed.
- Not fixable from this codebase: the app can't appear in System Settings' per-app Text Size list
  (Accessibility → Display → Text Size) — confirmed via Apple Developer Forums (including a DTS
  engineer reply) that this is currently a curated allowlist of Apple's own apps only, with no
  third-party registration mechanism.

## Repo state

- `main` is current (`24b962a` as of this session — Stage 17 — committed **and pushed** to
  `origin/main`, along with Stages 14–16 which were still unpushed at this session's start); no other
  active branches.
- Working tree clean once this session's documentation commit lands.
- `Slideshow/` is organised into `App/`/`Views/`/`Views/ViewModels/`/`Models/`/`Services/`/
  `Extensions/` (Stage 11 housekeeping — file moves only, no code changes). `Info.plist`,
  `Slideshow.entitlements`, `Assets.xcassets`, and `Preview Content/` stay flat under `Slideshow/`,
  matching the team's standard template. `Services/` gained `SecurityScopedAccess.swift` and
  `GrantedFolderStore.swift` in Stage 16, and `CursorIdleHider.swift` in Stage 17; `Views/` gained
  `SlideView+FullScreen.swift`; `Extensions/` gained `View+NavigationDocument.swift`.
- A project-local `.gitignore` now exists (added Stage 17) — currently just `Logs/`, where Console.app
  captures get pasted in during debugging sessions (not meant to be tracked). Everything else
  (`.DS_Store`, `.claude/`, Xcode user data) is still excluded via the user's global git config, not
  this file.
