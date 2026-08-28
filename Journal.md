# The Slideshow Journal

## The Big Picture

Picture the simplest slideshow app there is: You point it at a folder of photos, it shows them
full-screen one at a time, and that's the whole pitch. No albums, no editing, no cloud sync, no
AI-powered "memories." Just: here's a folder, there are photos in it, show them to me, one after
another, nicely.

That restraint is the actual feature. Every time a "wouldn't it be nice if…" idea comes up, the
answer defaults to **No** unless it's in direct service of "show me these photos, full-screen, without
fuss." What *is* in scope: remembering where you left off, opening sensibly from Finder and the Dock,
zooming in on a photo, and multiple windows behaving like a proper Mac app expects them to. What's
deliberately not in scope: pretty much everything else.

## Architecture Deep Dive

Think of `ContentView.ViewModel` as the manager of a single photo booth. It knows which folder of
photos this particular booth is showing, which one's currently up on the screen, and it can go fetch
a new folder when asked. Crucially, it doesn't know or care that there might be *other* booths
(windows) elsewhere in the building — that's not its job.

`AppCoordinator` is the building manager. It doesn't run any individual booth, but it knows about all
of them, and it handles the things that only make sense from a bird's-eye view: "when we reopen after
closing for the night, which booths were showing what?", "a new photo just arrived at the front desk
(Finder/Dock) — does an empty booth already exist to put it in, or do we need a new one?", "we're
closing up — don't let each booth's shutdown mess up what we've already written down for tomorrow."

The trickiest part of this building-manager metaphor, and the part that actually broke twice during
development, is *ordering*. The building manager's morning checklist (`bootstrapLaunchIfNeeded`) has
to run and read yesterday's notes *before* any booth's own "I've just opened, let me register myself"
routine gets a chance to overwrite those notes with "nothing here yet." Get that backwards — even
briefly, even just for one line of code — and every booth opens empty, because the manager wiped the
notes before reading them. That's not a hypothetical; it's exactly what happened, twice, and both
times the fix was purely about *order*, not about the underlying logic being wrong.

The other structural decision worth understanding: `Slide` objects (and the `[Slide]` array) carry
real `Identifiable` identity via `UUID`. Early on, images lived in a `[String: Image]` dictionary —
which sounds harmless, but SwiftUI leans hard on identity to decide what's "the same view, just
updated" versus "a brand new view that should transition in." Without real identity, SwiftUI got
confused about whether a crossfading photo was the same view or a new one, which showed up as a
bizarre stray vertical line during transitions — and the first attempted fix (slapping `.id()` on
things) traded that bug for a worse one: every keyboard shortcut stopped working, because the `.id()`
churn was recreating the *whole view subtree*, focus handlers included, on every slide change. The
actual fix needed both halves: give the *photo* real identity, but keep focus/keyboard handling on a
part of the view tree that *never* churns.

## The Codebase Map

- `ContentView.swift` / `ContentView+ViewModel.swift` — one window's state and the logic that loads
  a folder into it. If you're chasing "what happens when a folder gets picked," start here.
- `DefaultView.swift` — the picker screen (folder not yet loaded, or between slideshows). Pure view;
  no file I/O of its own any more.
- `SlideView.swift` — the full-screen slideshow itself: navigation, zoom, auto-advance, metadata.
- `Slide.swift` — the per-image model with real identity.
- `AppCoordinator.swift` — cross-window and app-lifecycle logic: multi-window restore, Finder/Dock
  open routing, closing stale windows.
- `AppDelegate.swift` — thin `NSApplicationDelegate`; just flags when the app is quitting so
  `AppCoordinator` can tell that apart from an individual window closing.
- `WindowState.swift` / `WindowStateStore.swift` — the persisted (folder bookmark, selected image)
  pair and its `UserDefaults` storage.
- `FocusedSlideshowWindow.swift` — the bridge letting app-level menu commands reach the frontmost
  window's state, since `.commands` live outside the normal view hierarchy.
- `SlideshowApp.swift` — the `App` entry point: scenes (main window, Help, About, Settings) and
  commands.
- `Settings.swift` / `SettingsView.swift` / `AboutView.swift` / `HelpView.swift` — auxiliary windows.
- `ScrollZoomView.swift` — a small AppKit bridge for trackpad/mouse-wheel zoom, since SwiftUI has no
  native scroll-delta gesture.
- `SlideshowTests/ContentViewModelTests.swift` — real Swift Testing coverage for the view model,
  using genuine temp directories and image files.

## Tech Stack & Why

- **SwiftUI**, almost exclusively — this app has no need for UIKit/AppKit-level control except in the
  two places SwiftUI genuinely has no native equivalent (scroll-wheel deltas, full-screen toggling on
  a specific `NSWindow`), where small, deliberate AppKit bridges exist instead of fighting the
  framework.
- **`@Observable`**, not `ObservableObject` — modern Observation framework, less boilerplate, and the
  project standard per the team's own conventions.
- **Swift Testing**, not XCTest, for `ContentViewModelTests` — `@Test`/`#expect`/`#require` read more
  like plain assertions, and tests run in parallel by default. XCTest is still used for the (untouched,
  boilerplate) UI test target, since Swift Testing doesn't support UI tests.
- **Security-scoped bookmarks**, because the app is sandboxed and "remember this folder across a
  relaunch" is a first-class requirement — this is *the* standard Apple-sanctioned mechanism for
  exactly that, not a workaround.
- **Explicit, hand-rolled window-state persistence** (`UserDefaults` + `AppCoordinator` replay) rather
  than SwiftUI/AppKit's built-in scene restoration — deliberately, because that built-in mechanism is
  gated behind a user-toggleable system setting ("close windows when quitting"), which would make the
  restore feature *quietly* stop working for some users depending on a checkbox this app has no
  control over. Reliability mattered more here than reusing a free framework feature.

## The Journey

**The vertical-line mystery.** A stray vertical line would appear during crossfades, sometimes, on
some photos, and pausing auto-advance made it vanish. That "pausing makes it go away" clue was the
real hint — it pointed at the *animation*, not the image data. Several red herrings were chased first
(a suspected `ScrollZoomView` interaction, an `NSImage` multi-representation theory, a `.frame()`
modifier) before landing on the actual cause: no real per-slide identity, so SwiftUI's transition
system was getting confused about which view was which mid-crossfade.

**The `.id()` trap.** Adding `.id(currentImageName)` fixed the vertical line immediately — and broke
every keyboard shortcut in the same commit. The lesson, in hindsight, is almost too neat: identity
churn doesn't just affect the view you're trying to give identity to, it affects *everything nested
inside it*, including focus state. The fix wasn't "don't use `.id()`," it was "put `.id()` only on the
thing that actually needs fresh identity, and make sure focus/keyboard handling lives somewhere that
never gets torn down."

**Two ordering bugs in one feature.** Multi-window restore (Stage 5) shipped its core logic
correctly the first time — and still failed, intermittently, because of *when* things ran relative to
each other, not *what* they did. Bug one: a "just in case" persistence refresh was running before the
launch-restore code had a chance to read what was saved, wiping it. Bug two: the very window that
*ran* the restore bootstrap was also checking "is there anything queued for me?" afterwards — and
occasionally stole the entry meant for the *next* window, leaving that one empty. Both were found via
`OSLog` tracing and a genuinely surprising console log ("windowStateDidChange: persisting 0 state(s)
from 0 registered window(s)") rather than by staring at the code and reasoning it out — a good
reminder that for anything involving app lifecycle timing, adding structured logging and *looking at
what actually happened* beats theorising about what *should* happen.

**The Finder/Dock dead end that wasn't a dead end.** The original plan for reusing an empty window on
a Finder/Dock open assumed `AppDelegate.application(_:open:)` was the delivery mechanism, with
`AppCoordinator` deciding whether to reuse a window *before* SwiftUI created one. Testing proved that
assumption wrong: SwiftUI's `WindowGroup` + `CFBundleDocumentTypes` handles these events itself,
creating and showing a window before the delegate method ever runs — confirmed by the complete
*absence* of any `AppCoordinator` log line around a Dock-drop event, not by a stack trace or an error.
Rather than fight the framework, the fix flipped the approach: let the new window happen, then clean
up a stale empty one elsewhere, achieving the same end state (no redundant window) from the other
direction.

**Sandbox reality checks.** Two separate discoveries here, both counter-intuitive at first: (1) a
folder handed over by Finder's "Open With" or a double-click only grants access to *that one file*,
not its containing folder — no way to ask for more afterwards — which is why the app declined to try
supporting single-image opens at all, rather than half-support a scenario the sandbox will never
actually allow to work smoothly. (2) Security-scoped bookmarks track the underlying filesystem item,
not a path string — so they transparently survive a rename or a move (even into the Trash), and only
fail once the item is genuinely gone. That second one looked like a bug the first time it was seen
("I moved the folder and it still found it?!") and turned out to be exactly the intended, designed
behaviour.

## Engineer's Wisdom

- **When something's intermittent, don't reason about it — log it and reproduce it.** Both Stage 5
  ordering bugs would have taken far longer to find by code review alone; structured `OSLog` tracing
  turned "sometimes it doesn't work" into an obvious, single-line smoking gun within a couple of
  iterations.
- **A wrong assumption about a framework's behaviour is worth testing directly, not just reading
  about.** The Finder/Dock delivery-path assumption was plausible-sounding and wrong; the fix was
  discovered by testing, not by re-reading documentation more carefully.
- **Sandbox restrictions are usually not bugs to work around — they're the platform telling you what
  UX is actually achievable.** Two separate points in this project (single-file Finder opens, the
  "reuse an empty window" feature) turned into *better* designs once the instinct to fight the
  platform gave way to designing within its real constraints.
- **Order-of-operations bugs hide well in code review and show up immediately in logs.** If a feature
  touches app/window lifecycle, assume timing bugs are likely and instrument accordingly *before*
  they're needed, not after the second one bites.

## If I Were Starting Over…

The `[String: Image]` dictionary would never have existed — `Slide` with real `Identifiable` identity
would have been the model from day one, sidestepping the vertical-line saga entirely. Beyond that,
honestly, not much: the willingness to test assumptions empirically (Console.app, `OSLog` tracing)
rather than trust them turned out to be the thing that actually mattered each time something got
tricky, and that's a habit worth keeping rather than a mistake worth avoiding.
