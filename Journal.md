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

As of the Stage 11 housekeeping pass, `Slideshow/` is organised by role rather than one flat folder
of ~24 files — the layout now matches the team's standard `App/Views/Models/Services/Extensions`
structure:

- `App/ContentView.swift` / `Views/ViewModels/ContentView+ViewModel.swift` — one window's state and
  the logic that loads a folder into it. If you're chasing "what happens when a folder gets picked,"
  start here. `ContentView` also owns zoom/pan/Help state on behalf of `SlideView` these days (see
  below), and the shared `@Namespace` that drives the hero-image morph.
- `Views/DefaultView.swift` — the picker screen (folder not yet loaded, or between slideshows). Pure
  view; no file I/O of its own.
- `Views/SlideView.swift` — the full-screen slideshow itself: navigation, zoom, pan, auto-advance,
  metadata, context menu, accessibility actions. The biggest single file in the project by a wide
  margin — worth skimming its doc comments before making changes here.
- `Models/Slide.swift` — the per-image model: real identity via `UUID`, plus (since Stage 10) the
  slide's own file `URL`, needed for Copy/Reveal in Finder/Share. Since Stage 15, that's *all* it
  carries — no decoded image any more; see `ContentView.ViewModel.loadedImage(for:)`.
- `App/AppCoordinator.swift` — cross-window and app-lifecycle logic: multi-window restore, Finder/Dock
  open routing, closing stale windows.
- `App/AppDelegate.swift` — thin `NSApplicationDelegate`; just flags when the app is quitting so
  `AppCoordinator` can tell that apart from an individual window closing.
- `Models/WindowState.swift` / `Services/WindowStateStore.swift` — the persisted (folder bookmark,
  selected image) pair and its `UserDefaults` storage.
- `Views/ViewModels/FocusedSlideshowWindow.swift` — the bridge letting app-level menu commands reach
  the frontmost window's state, since `.commands` live outside the normal view hierarchy. Grew a lot
  in Stage 10: `toggleHelp`/`resetZoom`/`copyImage` closures alongside the original
  `startAtCurrent`/`restartFromBeginning`.
- `App/SlideshowApp.swift` — the `App` entry point: scenes (main window, Help, About, Settings) and
  commands, including the whole "Slideshow" menu added in Stage 10.
- `Views/SettingsView.swift` / `Views/AboutView.swift` / `Views/HelpView.swift` — auxiliary windows.
- `Views/ScrollZoomView.swift` / `Views/ZoomGestureDetector.swift` — the AppKit bridge for
  trackpad/mouse-wheel zoom *and* pinch-to-magnify *and* declining right-clicks so they fall through to
  SwiftUI's context menu underneath. See "The overlay that ate everything" below for why it grew two
  extra jobs it wasn't originally built for.
- `Services/ShareSheetPresenter.swift` — a small `NSSharingServicePickerDelegate` wrapper so the Share
  Sheet can be anchored at the mouse pointer instead of `ShareLink`'s automatic (and, full-screen,
  broken) positioning.
- `Services/SecurityScopedAccess.swift` (Stage 15) — the one shared "resolve bookmark → open access →
  do the work → close it" helper, used by lazy slide decoding, Copy, Share, and (Stage 16) the
  granted-folder fallback. Used to be duplicated as `ContentView`'s private `withFolderAccess(_:)`.
- `Services/GrantedFolderStore.swift` (Stage 16) — persists every folder ever granted, independent of
  any one window, deduplicated to the highest granted ancestor. See "The gap that wasn't where it
  looked" below, and Stage 17's follow-up, "The gap inside the gap."
- `Services/CursorIdleHider.swift` (Stage 17) — hides the mouse cursor after a few idle seconds while
  full-screen, revealing it on movement or full-screen exit. Watches real `NSWindow` full-screen
  notifications rather than `SlideView`'s own toggle calls, since Cmd-F can exit full-screen
  independently via the menu.
- `Views/SlideView+FullScreen.swift` (Stage 17) — `captureWindowIfNeeded()`/`exitFullScreen()`, split
  out of `SlideView.swift` itself purely to stay under SwiftLint's type-body-length limit once
  `CursorIdleHider` wiring was added — no behaviour change, just a file split.
- `Extensions/Animation+ReduceMotion.swift`, `Extensions/NSPasteboard+Image.swift`,
  `Extensions/View+NavigationDocument.swift` (the last one, Stage 17, is an optional-`URL` overload of
  `.navigationDocument(_:)`, which annoyingly only takes a non-optional `URL`) — small, focused
  extensions shared across multiple views.
- `SlideshowTests/ContentViewModelTests.swift` — real Swift Testing coverage for the view model, using
  genuine temp directories and image files. `SlideshowTests/GrantedFolderStoreTests.swift` (Stage 16)
  covers the ancestor-dedup logic directly, via an isolated `UserDefaults` suite per test. 36 tests
  total as of Stage 17.

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
- **`matchedGeometryEffect`**, not the newer `matchedTransitionSource`/`.navigationTransition(.zoom)`,
  for the hero-image-to-slide morph (Stage 9) — the newer API is genuinely built for `NavigationStack`
  push/pop specifically, and this app deliberately doesn't use one (a simple boolean-flag ZStack swap
  has always been the whole navigation model here). `matchedGeometryEffect` is the older, more
  general-purpose tool for exactly this "two views, one shared identity, animate between them" job.

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

**The overlay that ate everything.** `ScrollZoomView`'s backing NSView has to sit on top of the whole
slide area to catch scroll-wheel events — that was true from day one. What wasn't obvious until Stage
8 is that "sits on top to catch one event type" quietly means "sits on top and can swallow *other*
event types too, even ones nobody asked it to touch." Pinch-to-zoom went in as a textbook SwiftUI
`MagnifyGesture` on the image underneath — and did precisely nothing, because the overlay was
intercepting the raw magnify `NSEvent` first and just... not doing anything with it. The fix was to
stop fighting the overlay and let it do the job properly: override `magnify(with:)` right alongside
the existing `scrollWheel(with:)`, feeding both into the same `setScale` path. Two stages later, the
exact same shape of bug came back for right-clicks: `.contextMenu` on the image did nothing either,
for the identical reason. Interestingly, tap-to-advance and drag-to-pan — both plain SwiftUI
`.gesture()`/`.onTapGesture()` — had been working fine the whole time, sitting under the same overlay.
The lesson that fell out of comparing the two: SwiftUI's own gesture recognizers apparently ride on a
different, more privileged event path than the classic AppKit `rightMouseDown`/`menu(for:)`
hit-testing that `.contextMenu` and pinch/magnify both go through — so "one gesture type works, a
different one doesn't, both attached to views under the same overlay" isn't a contradiction, it's a
clue. The eventual fix for right-clicks (a `hitTest(_:)` override that just declines them outright)
was a five-line addition once that distinction clicked — the hard part was noticing there even *was*
a pattern connecting two bugs two stages apart, rather than debugging each one from scratch as if
unrelated.

**The security scope that closed behind us.** Stage 10 added Copy/Reveal in Finder/Share for the
displayed image. Reveal in Finder worked first try. Copy and Share both silently did nothing. The
difference, once spotted: Reveal in Finder just hands a file *path* to Finder, a separate process —
it never needs *this* sandboxed app to actually read the bytes. Copy and Share both do. And the
security-scoped access that let `getImagesAtURL` read those bytes in the first place had already
closed by the time a user got around to clicking Copy — for a restored window, `resume(from:)`
explicitly opens and closes that access window in one tight `defer`-bracketed call, on the (until
then, entirely reasonable) assumption that nothing would ever need file access again after the eager
load finished. Copy and Share were the first features to break that assumption. The fix mirrors what
`resume(from:)` already does — re-resolve the folder's bookmark and briefly reopen scoped access on
demand — rather than inventing something new. Share needed one more wrinkle on top: the Share Sheet's
lifetime is asynchronous and open-ended (however long the user takes to pick a destination), far
longer than any synchronous re-scoped window could safely stay open, so it copies to the temp
directory first and shares *that* — always accessible, no scoping required.

**One name tag, worn by everyone.** The hero-image-to-slide morph (Stage 9) uses
`matchedGeometryEffect` with a shared `"hero"` id between `DefaultView`'s hero image and whichever
slide `SlideView` is showing. First pass: tag *every* slide with that same id. Result: the intended
hero morph worked perfectly — and ordinary slide-to-slide navigation (plain space-bar presses)
started doing bizarre grow/slide animations instead of the expected crossfade. The reason took a
moment to land: `.id(slide.id)` already gives each slide fresh SwiftUI identity per photo (that's the
whole point, from the very first vertical-line saga) — so navigating from slide 3 to slide 4 looks,
from `matchedGeometryEffect`'s perspective, exactly like "a view tagged `hero` disappeared while
another view tagged `hero` appeared," which is precisely the trigger condition for a matched-geometry
animation. Two views sharing one name tag will get treated as *the same thing in transit* by SwiftUI,
whether or not that's what was intended. The fix was a boolean (`isHeroTransitionSlide`) scoping the
shared tag down to only the actual boundary moments — first slide in, last slide showing on the way
out — with every other slide getting a unique, un-shared id instead.

**A menu item that stayed disabled no matter what.** Cmd+C for Copy seemed like the obvious use for
`CommandGroup(replacing: .pasteboard)` — it's *the* standard placement for Cut/Copy/Paste, after all.
It compiled, it showed up in the Edit menu, `.disabled(false)` was set explicitly — and pressing Cmd+C
still did nothing. That placement, it turns out, ties itself to AppKit's classic `copy(_:)`
responder-chain selector under the hood, a decades-old Cocoa mechanism this SwiftUI-only app has no
responder implementing at all — and that old validation path appears to override SwiftUI's own
explicit enable/disable state for exactly the handful of "standard" edit-menu placements. Moving the
same button into the app's own bespoke `CommandMenu("Slideshow")` — no inherited selector, no
ambiguity — fixed it immediately. Worth remembering: the "correct-looking," most-specific SwiftUI API
for a job isn't always the right one if that API's whole reason for existing is to hook into older
platform machinery your app doesn't otherwise use.

**A recurring false alarm worth naming.** All through Stages 6–11, editing one file would routinely
make the *live* SourceKit diagnostics light up with things like "Cannot find type 'ContentView' in
scope" — sometimes across half the project — immediately after a perfectly ordinary edit, especially
right after a file got moved or split. Every single time, an actual `xcodebuild`/Xcode-MCP build
right after came back clean. The pattern held reliably enough to trust: these were the live editor
index lagging behind on-disk changes, not real errors — worth remembering for next time before
chasing a phantom. Held again through Stages 14–16 without exception.

**The backlog wasn't what the plan said it was.** Session start for Stages 14–16 began with `Plan.md`
confidently stating "1 outstanding issue" left. Clarity's own issue list said 4. Two of them — the
Enter-to-start polish and the granted-folder feature — had simply never made it into the plan document
at all. Nobody had done anything wrong; the tracker and the plan had just quietly drifted apart. Worth
a standing habit: when a plan document and the actual issue tracker disagree, the tracker wins, and
it's worth checking whenever picking up new work rather than trusting a plan file's summary of "what's
left" to still be current.

**The gap that wasn't where it looked.** p534 read, on the surface, like a picker/UX request — "let me
grant a high-level folder once and browse anywhere inside it." The obvious-looking fix (a custom
in-app folder browser, or smarter `NSOpenPanel` pre-population) would have been solving the wrong
problem entirely: `NSOpenPanel` already works regardless of prior grants, full stop, no feature needed
there at all. The actual gap, once Paul reframed it, was much narrower and already half-documented in
the codebase's own comments: dropping a single *file* (not a folder) onto an existing window only ever
grants access to that one file, and enumerating its parent folder fails unless the app *already* has
broader access — and "already has" only ever meant "this session." The fix (`GrantedFolderStore`)
ended up much smaller than the imagined one, because the real requirement was smaller too. Worth
asking "what specifically fails, and when?" before designing a fix for what a feature request sounds
like it's asking for.

**Read the whole issue, not just its title.** Stage 15 (`p406`) was implemented off a one-line summary
from a project-wide issue list — title and status only, not the actual description or its comments.
The comments turned out to contain real, specific constraints ("if there are no windows open, memory
should be effectively zero") that the eventual design happened to satisfy anyway, and one comment (a
claimed "high-level folder" recursion causing tens-of-gigabytes blowouts) that didn't match anything
the current codebase actually does — most likely a leftover description of the `FileSystemReader.swift`
dead code removed in an earlier, unrelated stage. Nothing broke this time, but it easily could have:
a documented constraint could just as easily have been missed entirely by working from the summary
alone. Read the full issue — description and comments both — before implementing, not just its
one-line title from a list view.

**A folder that could be seen but not selected.** Verifying Stage 16 in the running app surfaced a
separate, pre-existing bug: the "Select Folder or Image…" panel let you navigate *into* a folder but
never actually *select* one — only images could be chosen. Root cause: `NSOpenPanel.allowedContentTypes`
was set to just the image UTTypes, with no `.folder` in the list, and `canChooseDirectories = true`
doesn't override that — a folder that conforms to none of the listed content types simply can't be the
thing you pick, regardless of that flag. A one-line fix (`.folder` added to the list) once spotted, but
a good reminder that `canChooseDirectories` and `allowedContentTypes` are two independent gates that
both have to agree, not one flag that implies the other.

**The gap inside the gap.** Stage 16 fixed the headline case of "drag a lone file, fall back to a
previously-granted ancestor folder" — and Paul's own real-world testing (Stage 17, p370) found a second
gap hiding inside the first one. His photo library is organised as folder-of-folders: a top-level
"Sets" folder containing one subfolder per photoshoot, each of *those* containing the actual images —
so the top-level folder itself never has any images directly inside it. `getImagesAtURL` only ever
called `recordGrantedFolder` inside the branch where the *current* folder's own `loadedSlides` was
non-empty — which meant that top-level folder, despite loading successfully every time it was dropped,
was never actually persisted to `GrantedFolderStore`. Only the individual subfolders Paul had happened
to visit directly got remembered. After a relaunch, dragging an image from any subfolder he *hadn't*
separately visited still failed, because neither it nor its true ancestor was on record — only
unrelated sibling subfolders were. The first diagnostic pass logged counts ("20 stored, match=none")
and chased a plausible-but-wrong theory (symlink resolution on the `/Volumes/...` external drive); the
second pass logged the *actual list* of all 20 stored paths, and the pattern was obvious on sight —
every single one was a leaf folder, no top-level folder anywhere in the list. The fix was one line moved
to a different branch: record on any successful enumeration, not just one that happens to find images
directly inside it.

**The button that couldn't shine.** p371 sat unexplained for a while: hitting Enter always did the
right thing (selected a folder, or started the slideshow), but the "default button" pulsing highlight —
the usual macOS cue for "this is what Enter will do" — simply never appeared, and only on Paul's
secondary machine running macOS 15.7.9. Reasoning about SwiftUI/AppKit's internal default-button
rendering from first principles would have been a rabbit hole; instead, one cheap, two-minute
experiment settled it directly: comment out `.buttonBorderShape(.circle)` (from Stage 7's circular
icon-button redesign) and rebuild. The highlight came back immediately. Circular buttons, on that OS
version at least, simply don't get the pulse animation SwiftUI draws for every other border shape — a
rendering-path gap, not a logic bug, and not something reasoning about the code alone would have
surfaced nearly as fast as just testing the one suspicious modifier directly.

**The alphabet that shouted.** Between sessions, Paul noticed `file12` turning up before `file2` and
fixed it with `compare(_:options: .numeric)` — the classic "natural sort". It worked, but it only
fixed half of the gap with Finder. A plain `compare` is still case-sensitive, and in Unicode every
capital letter comes before every lowercase one, so `Beach.jpg` would happily barge in ahead of
`apple.jpg`. Think of a library shelf where every title in capitals has been put on a shelf of its
own. The fix was to stop building Finder's ordering by hand and just ask for it:
`localizedStandardCompare(_:)` is Apple's "sort like Finder" API — numeric-aware, case-insensitive,
and it follows the user's locale. The new regression test (`B.png`, `a.png`, `c.png` → `a, B, c`) was
written first and watched failing with `B, a, c` before the fix went in, so it's proven to catch the
bug rather than just pass. It's the first test in the project tagged with its Clarity issue
(`.clarity(596, …)`) via the newly linked `ClarityTesting`.

A small side quest: that one extra test pushed `ContentViewModelTests` to 253 lines, three over
SwiftLint's `type_body_length` limit. Rather than raise the limit, the existing alphabetical and
natural-order tests were merged into a single parameterised `@Test(arguments:)`. It was the same test
written twice with different file names, so merging it removed real duplication rather than just
lines. And the session opened with a lint warning nobody had caused: upgrading SwiftLint to 0.65.1
added a `legacy_swiftui_aspect_ratio` rule, which flagged `.aspectRatio(contentMode: .fit)` — swapped
for the identical `.scaledToFit()`.

**The icon that took off its Beta badge.** Slideshow's icon had worn a blue "Beta" banner since 2023.
The replacement went through two rounds on a review page: six directions, then three recolours of the
winner. The final design is a framed sunset photo with an orange play button, on Xerodonia blue. The
plan was to have it both ways: a Liquid Glass `.icon` for macOS 26, and the old-style asset-catalog
icon kept for macOS 15. Apple's docs killed that idea before any work went into it. An Icon Composer
file *replaces* the asset catalog's icon outright, and Xcode renders the older-OS version itself at
build time. It's a bit like a translator who insists on doing every language, the original included.

Trusting the generated icon still meant looking at it. The built app's `AppIcon.icns` converts to a
PNG with one `sips` command, and that render caught two problems that looked fine in Icon Composer's
dark preview. First, the gradient had only been set for the *dark* appearance, so the default icon
was Icon Composer's stock sky-blue. Second, the glass translucency let the blue soak through the
orange badge until it looked like weak tea. The About window then got the simplest fix of all: show
`NSApplication.shared.applicationIconImage` instead of keeping a second copy of the artwork. One copy
of the icon is the only copy that can't fall out of date.

**Four signatures and a parcel.** The first TestFlight upload was a lesson in how many times a Mac app
gets signed on its way to Apple. Think of posting a parcel. The *archive* is the packed box: a
Release build with its debug symbols, signed with Paul's everyday development certificate, like a
name scrawled on the flap. The *export* is the post-office counter. It re-signs the app with an
**Apple Distribution** certificate, tucks a Mac App Store provisioning profile inside (the customs
form saying which team owns this app), and wraps it all in a `.pkg`. The package then gets its own
signature from the **Mac Installer Distribution** certificate. `pkgutil` still calls that one by its
old name, "3rd Party Mac Developer Installer", and labels it "(Development)", which looks alarming
until you learn it's normal. Neither distribution certificate existed until the export asked
for them. With `-allowProvisioningUpdates`, Xcode quietly created both in Paul's account, which is
why that step got its own go-ahead. The *upload* posts the parcel. App Store Connect then opens it
and checks everything — the signatures, the privacy manifest, the encryption flag — before calling it
`VALID`.

One detail is easy to trip over: the project's `CURRENT_PROJECT_VERSION` says 31, but the build that
went up was 58. The "Update Build Number" phase stamps the git commit count into the finished
`Info.plist` after Xcode has used the project setting. So `asc`'s own version-editing commands are
best left alone here, or they'd fight the script.

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
- **When the same shape of bug appears twice, look for the shared cause before fixing the second one
  from scratch.** The pinch-to-zoom and right-click bugs (Stages 8 and 10) were the identical root
  cause — an overlay view claiming events other code underneath needed — two stages apart. Recognising
  that connection turned the second fix into five minutes instead of a fresh investigation.
- **An assumption baked into a working feature can quietly become wrong the moment a new feature needs
  more from it.** `resume(from:)`'s "access only needed for the eager load" design was entirely correct
  *until* Copy/Share needed file access again, later, for reasons that design never had to consider.
  Not a bug in the original code — a reminder to re-examine old assumptions specifically when a new
  feature leans on the same subsystem in a new way, rather than assuming "it already works" covers it.
- **The most specific-looking API for a job isn't automatically the right one.** `CommandGroup
  (replacing: .pasteboard)` reads like the obviously-correct SwiftUI placement for Copy — right up
  until its coupling to old Cocoa selector validation makes it silently not work for an app with no
  responder chain implementing that selector. A more generic, bespoke command sidestepped the whole
  problem. Worth asking "what older machinery does this specific API hook into?" before reaching for
  the most on-the-nose-sounding one.
- **A one-line issue-list summary is not the issue.** Working from a title-and-status list rather than
  the full description and comments risks silently missing constraints someone already wrote down.
  Read the whole tracked issue before implementing against it, every time — not just when something
  seems ambiguous.
- **Reframe a feature request around its actual failure mode before designing the fix.** p534 sounded
  like a UX feature (picker convenience); the real requirement, once traced to its actual trigger
  (single-file drag-and-drop across sessions), was narrower and simpler than the imagined version.
  Designing for the request as first phrased would have built real UI for a problem that didn't exist.
- **A logging *count* can mask the very pattern a logging *list* reveals instantly.** "20 stored,
  match=none" (p370) is consistent with a dozen different theories; the actual list of all 20 paths
  made the real cause ("every single one is a leaf folder") obvious in one glance. When a summary
  statistic doesn't explain a bug, log the raw data behind it before reasoning further about the
  summary.
- **A visual/rendering quirk is often faster to isolate by testing one suspicious modifier directly
  than by reasoning about the framework's internals.** p371's missing default-button highlight took one
  two-minute experiment (comment out `.buttonBorderShape(.circle)`, rebuild) to root-cause, on the exact
  OS version the bug was reported on — reasoning about SwiftUI/AppKit's rendering pipeline from first
  principles would have taken far longer for the same answer.
- **Diagnostic `OSLog` added specifically to chase a bug is worth keeping afterwards, same as the
  window-lifecycle logging from Stage 5.** The `enumerate(_:)`/`GrantedFolderStore`/
  `SecurityScopedAccess` logging added to diagnose p370 stayed in the codebase once the bug was found
  and fixed — sandbox/grant logic is exactly the kind of intermittent-by-nature code worth being able
  to debug via Console.app again without re-instrumenting first.
- **When the platform already has a name for the behaviour you want, use it instead of rebuilding it
  from options.** "Sort like Finder" isn't `.numeric` plus `.caseInsensitive` plus whatever else you
  remember — it's `localizedStandardCompare`, and it will keep matching Finder as Apple changes it.
  (Same instinct as `localizedStandardContains` for filtering user input.)
- **A new lint warning on unchanged code usually means the linter changed, not the code.** Check the
  tool's version before going looking for a regression.
- **Read the platform docs before planning around a build tool.** "Keep both icon formats" sounded
  sensible and wasn't possible. One documentation search changed the plan before anyone built an
  icon set that Xcode would have ignored.
- **Check generated output, not just the source.** Icon Composer looked right; the `.icns` Xcode
  actually shipped showed the wrong fill and a muddy badge.

## If I Were Starting Over…

The `[String: Image]` dictionary would never have existed — `Slide` with real `Identifiable` identity
would have been the model from day one, sidestepping the vertical-line saga entirely. The
`App/Views/Models/Services/Extensions` folder structure (only adopted in Stage 11, as a pure
housekeeping pass with zero code changes) would have been there from the first commit too — with ~24
files eventually accumulating in one flat folder, organising by role early would have cost nothing and
saved a session's worth of "where does this file actually live" later. Beyond that, honestly, not
much: the willingness to test assumptions empirically (Console.app, `OSLog` tracing, and — new this
round — actually looking up Apple's own platform documentation/forums rather than guessing at
undocumented system behaviour) turned out to be the thing that actually mattered each time something
got tricky, and that's a habit worth keeping rather than a mistake worth avoiding.
