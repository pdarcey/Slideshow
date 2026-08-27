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

/// What a freshly-appeared `ContentView` should load, handed off by
/// whichever mechanism decided a new window was needed: a Finder/Dock file
/// open, or launch-time restoration of a previously-open window.
enum PendingOpen {
    case url(URL)
    case restoredState(WindowState)
}

/// Bridges Finder/Dock file-open events (delivered to `AppDelegate`, which
/// isn't a View and so has no `@Environment`) into SwiftUI's window-opening
/// machinery, decides whether to reuse an already-open empty picker window
/// or open a new one, and drives explicit multi-window restoration at
/// launch.
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

    /// What a newly-appeared window should load, one entry consumed per
    /// window. Populated either by `open(_:)` (Finder/Dock) or
    /// `bootstrapLaunchIfNeeded` (launch-time restore of a 2nd+ window).
    private var pendingOpens: [PendingOpen] = []

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

    /// Pops the next thing a freshly-appeared window should load, if any.
    func consumePendingOpen() -> PendingOpen? {
        guard !pendingOpens.isEmpty else {
            logger.info("consumePendingOpen: queue empty")
            return nil
        }
        let popped = pendingOpens.removeFirst()
        logger.info("consumePendingOpen: popped \(String(describing: popped), privacy: .public), \(self.pendingOpens.count) left queued")
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
            pendingOpens.append(.restoredState(state))
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

    /// Routes a Finder/Dock-opened folder into an existing empty picker
    /// window if one exists, or opens a new window for it otherwise.
    ///
    /// Raising the specific empty window (rather than just activating the
    /// app) is a follow-up polish item — see the "reuse an existing empty
    /// window" Clarity issue.
    func open(_ url: URL) {
        registeredWindows.removeAll { $0.viewModel == nil }

        if let existing = registeredWindows.first(where: { $0.viewModel?.images.isEmpty == true })?.viewModel {
            let (folderURL, selectedImage) = existing.parseSelectedURL(url)
            existing.getImagesAtURL(folderURL, selectedImage: selectedImage)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            pendingOpens.append(.url(url))
            openWindowAction?(id: "contents")
        }
    }
}
