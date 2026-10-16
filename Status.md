# Status

_Last updated: 2026-10-16_

## Build & test health

- Builds clean (Xcode MCP `BuildProject`, Debug configuration).
- `SlideshowTests` (`ContentViewModelTests` + `GrantedFolderStoreTests`, Swift Testing): 36/36 test
  cases passing (one test is parameterised over two cases). The 2023 XCTest template file is gone (Stage 18).
- `ClarityTesting` linked into both test targets (Stage 18); bug-driven tests are tagged with their
  Clarity issue.
- `SlideshowUITests`: skipped by the default test plan (unmodified Xcode boilerplate; drives real
  windows/focus and takes over the machine when run).
- SwiftLint (0.65.1) runs on every build (added Stage 6); zero warnings across the project.
- `CFBundleVersion` bumps automatically from `git rev-list --count main` on every build. `MARKETING_VERSION`
  is now `1.2.0` (bumped deliberately by Paul after Stage 17).

## Release status

- **On TestFlight:** 1.2.0 (58), uploaded and processed (`VALID`) on 2026-10-16 (Stage 21). It expires
  2027-01-13. Paul is setting up TestFlight groups and distribution himself. The upload commands are in
  `CLAUDE.md` › "Releasing to TestFlight".
- The release setup is in place: privacy manifest, encryption setting, copyright line, automatic
  signing with cloud-managed distribution certificates, Hardened Runtime, App Sandbox and App Store
  category. App Store Connect app ID: `6823400593`.
- Still to do in App Store Connect:
  - External TestFlight testers need Beta App Review: a beta description, feedback email and test
    notes.
  - Before App Store submission: rename the version record from `1.0` to `1.2.0`, and add a privacy
    policy URL and the App Privacy answers ("Data Not Collected").
- Worth checking before App Store review: `NSAppleEventsUsageDescription` describes *receiving* folders,
  which normally needs no usage description. A reviewer may ask about it.

## What works today

- Full-screen slideshow of a folder's images: manual navigation (arrow keys, space, tap-to-advance),
  auto-advance, metadata overlay, in-app help overlay.
- Slides play in the same order Finder lists them by Name: numbers in natural order (`file2` before
  `file12`), case-insensitive, and locale-aware (Paul's `2c85bea`, then Stage 18, p596).
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
- New app icon (Stage 19): a Liquid Glass `AppIcon.icon` on macOS 26, with Xcode generating the flat
  version for macOS 15. The About window shows the real app icon, so it always matches the Dock.

## Known gaps (tracked in Clarity, not yet started)

- The new app icon hasn't been checked on a real macOS 15 machine yet (`p597`, Current). The icon
  Xcode generates for it looked right when rendered from the build.
- Multiple selectable slide-transition styles (fade/slide/flip/grow-shrink, `p292`) — deliberately
  deferred, low priority, large scope on its own. As of Stage 19, this is the *only* item left in
  Clarity's backlog for this project — every other tracked issue is Completed.
- Not fixable from this codebase: the app can't appear in System Settings' per-app Text Size list
  (Accessibility → Display → Text Size) — confirmed via Apple Developer Forums (including a DTS
  engineer reply) that this is currently a curated allowlist of Apple's own apps only, with no
  third-party registration mechanism.

## Repo state

- `main` was pushed to `origin/main` on 2026-10-16 (up to `21e438f`, Stage 21 docs), plus this session's
  end-of-session docs commit. No other active branches.
- ClarityTesting is a private package. If Xcode Cloud builds this repo, its first build after this push
  fails until the repository is authorised (pending agreements in App Store Connect, then **Repository
  Issue** on the failed build in Xcode's Report navigator › Cloud).
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
