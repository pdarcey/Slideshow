//
//  CursorIdleHider.swift
//  Slideshow
//
//  Created by Paul Darcey on 15/9/2026.
//

import AppKit

/// Hides the mouse cursor after a period of inactivity while the watched
/// window is full-screen, revealing it again on movement or as soon as
/// full-screen ends — matching Preview/Photos' full-screen viewing
/// behaviour (see p369). Tracks *actual* full-screen transitions via
/// `NSWindow` notifications rather than `SlideView`'s own
/// `toggleFullScreen` calls, since Cmd-F can also toggle full-screen
/// independently, via the app-level menu command.
///
/// Owns its own `NSEvent` local monitor and `NotificationCenter`
/// observers so `SlideView` doesn't need `NSCursor`/`NSEvent` details in
/// its own body — same reasoning as `ShareSheetPresenter`.
@MainActor
final class CursorIdleHider {
    private static let idleDelay: Duration = .seconds(2)

    private weak var window: NSWindow?
    private var mouseMoveMonitor: Any?
    private var enterObserver: NSObjectProtocol?
    private var exitObserver: NSObjectProtocol?
    private var hideTask: Task<Void, Never>?
    private var isHidden = false

    /// Starts watching `window` for full-screen transitions. Idempotent —
    /// calling it again with the same window is a no-op, so `SlideView`
    /// can call it from `captureWindowIfNeeded()` without tracking whether
    /// it already did.
    func start(watching window: NSWindow) {
        guard self.window !== window else { return }
        stop()
        self.window = window
        let center = NotificationCenter.default
        enterObserver = center.addObserver(
            forName: NSWindow.didEnterFullScreenNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.beginIdleTracking() }
        }
        exitObserver = center.addObserver(
            forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.endIdleTracking() }
        }
        if window.styleMask.contains(.fullScreen) {
            beginIdleTracking()
        }
    }

    /// Stops watching, reveals the cursor if currently hidden, and tears
    /// down the event monitor/observers. Safe to call repeatedly.
    func stop() {
        endIdleTracking()
        if let enterObserver { NotificationCenter.default.removeObserver(enterObserver) }
        if let exitObserver { NotificationCenter.default.removeObserver(exitObserver) }
        enterObserver = nil
        exitObserver = nil
        window = nil
    }

    private func beginIdleTracking() {
        window?.acceptsMouseMovedEvents = true
        mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.resetIdleTimer()
            return event
        }
        resetIdleTimer()
    }

    private func endIdleTracking() {
        hideTask?.cancel()
        hideTask = nil
        if let mouseMoveMonitor { NSEvent.removeMonitor(mouseMoveMonitor) }
        mouseMoveMonitor = nil
        reveal()
    }

    private func resetIdleTimer() {
        reveal()
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.idleDelay)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func hide() {
        guard !isHidden else { return }
        isHidden = true
        NSCursor.hide()
    }

    private func reveal() {
        guard isHidden else { return }
        isHidden = false
        NSCursor.unhide()
    }
}
