//
//  AppCoordinator.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.xerodonia.Slideshow", category: "AppCoordinator")

/// Holds weak references so a registry doesn't keep a closed window or its
/// view model alive.
private struct RegisteredWindow {
    weak var viewModel: ContentView.ViewModel?
    weak var window: NSWindow?
}

/// Bridges launch-time restoration (see `bootstrapLaunchIfNeeded`) into
/// SwiftUI's window-opening machinery, and cleans up a redundant empty
/// window left behind after a Finder/Dock open lands in a fresh one (see
/// `closeEmptyWindows(excluding:)`).
///
/// Restoration is deliberately explicit (persisted to `UserDefaults` via
/// `WindowStateStore`, replayed by hand here) rather than relying on
/// SwiftUI/AppKit's own scene restoration — Apple's docs note that's
/// "governed by a system setting [the user] can toggle on and off"
/// (macOS's "close windows when quitting"), which would make restoring
/// previous windows quietly stop working depending on a checkbox outside
/// this app's control.
///
/// `.shared` is a pragmatic exception to generally avoiding singletons —
/// there's exactly one `NSApplicationDelegate` for the app's lifetime, and
/// it needs a stable way to reach whichever `ContentView`s currently exist.
@Observable
@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private init() {}

    private var registeredWindows: [RegisteredWindow] = []
    var openWindowAction: OpenWindowAction?

    /// What a newly-appeared window should restore, one entry consumed per
    /// window, populated by `bootstrapLaunchIfNeeded` for each window beyond
    /// the first at launch.
    private var pendingOpens: [WindowState] = []

    private var hasBootstrappedLaunch = false

    /// Set by `AppDelegate.applicationShouldTerminate(_:)`, before any
    /// window starts tearing down for quit. While true, `unregister(_:)`
    /// skips re-persisting — every window disappearing because the app
    /// itself is quitting shouldn't shrink the restore list down to
    /// nothing; it should still reflect what was open right before
    /// quitting.
    var isTerminating = false

    func register(_ viewModel: ContentView.ViewModel, window: NSWindow) {
        logger.info("register: now tracking \(self.registeredWindows.count + 1) window(s)")
        registeredWindows.append(RegisteredWindow(viewModel: viewModel, window: window))
    }

    func unregister(_ viewModel: ContentView.ViewModel) {
        registeredWindows.removeAll { $0.viewModel === viewModel || $0.viewModel == nil }
        logger.info("unregister: \(self.registeredWindows.count) window(s) left, isTerminating=\(self.isTerminating)")
        guard !isTerminating else { return }
        windowStateDidChange()
    }

    /// Pops the next state a freshly-appeared window should restore, if any.
    func consumePendingOpen() -> WindowState? {
        guard !pendingOpens.isEmpty else {
            logger.info("consumePendingOpen: queue empty")
            return nil
        }
        let popped = pendingOpens.removeFirst()
        logger.info("consumePendingOpen: popped a restore, \(self.pendingOpens.count) left queued")
        return popped
    }

    /// Called once, from the very first `ContentView` to appear. Replays
    /// every window that was open at last quit: the first saved state loads
    /// directly into the window that's already appearing (so we never
    /// create a window only to close it again), and one additional window
    /// is opened per remaining saved state.
    ///
    /// Returns whether *this* call directly resumed a state into
    /// `viewModel` — when true, the caller must not also consult
    /// `consumePendingOpen()`, since window creation can happen
    /// synchronously enough that the bootstrap window would otherwise steal
    /// the entry meant for the next window this same call just queued.
    @discardableResult
    func bootstrapLaunchIfNeeded(into viewModel: ContentView.ViewModel) -> Bool {
        guard !hasBootstrappedLaunch else {
            logger.info("bootstrapLaunchIfNeeded: already bootstrapped, skipping")
            return false
        }
        hasBootstrappedLaunch = true

        let states = WindowStateStore.load()
        logger.info("bootstrapLaunchIfNeeded: loaded \(states.count) persisted window state(s)")
        guard let first = states.first else { return false }

        viewModel.resume(from: first)
        for state in states.dropFirst() {
            pendingOpens.append(state)
            logger.info("bootstrapLaunchIfNeeded: queued a restore and opening a new window for it")
            openWindowAction?(id: "contents")
        }
        return true
    }

    /// Recomputes the persisted window list from every currently-registered,
    /// non-empty view model. Called after any successful load (so state is
    /// never stale even across a force-quit, with no reliance on
    /// `applicationWillTerminate`) and after a window closes.
    func windowStateDidChange() {
        registeredWindows.removeAll { $0.viewModel == nil }
        let states = registeredWindows.compactMap { $0.viewModel?.currentWindowState() }
        logger.info("windowStateDidChange: persisting \(states.count) state(s) from \(self.registeredWindows.count) registered window(s)")
        WindowStateStore.save(states)
    }

    /// Closes any other registered window that's still empty, once
    /// `viewModel` has just successfully loaded a folder.
    ///
    /// SwiftUI always creates a brand-new window for a Finder/Dock open
    /// (there's no hook that fires before it's already shown — see the note
    /// on `AppDelegate`), so this can't *prevent* that window from
    /// appearing. Instead it cleans up the other side of the same problem:
    /// a pre-existing empty window left stranded once the new one has
    /// content. This closes the stale window rather than the new one, so
    /// nothing the user is actually looking at flashes in and out.
    func closeEmptyWindows(excluding viewModel: ContentView.ViewModel) {
        registeredWindows.removeAll { $0.viewModel == nil }
        for entry in registeredWindows {
            guard let entryViewModel = entry.viewModel,
                  entryViewModel !== viewModel,
                  entryViewModel.images.isEmpty else { continue }
            logger.info("closeEmptyWindows: closing a stale empty window")
            entry.window?.close()
        }
    }
}
