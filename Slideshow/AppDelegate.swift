//
//  AppDelegate.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import AppKit

/// Receives Finder/Dock file-open events (double-click, "Open With",
/// dragging onto the Dock icon) and hands them to `AppCoordinator`, which
/// decides whether to reuse an existing empty window or open a new one.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AppCoordinator.shared.open(url)
        }
    }

    /// Fires before any window starts tearing down for quit, so
    /// `AppCoordinator` can tell a genuine user-initiated window close
    /// (which should shrink the persisted restore list) apart from windows
    /// disappearing merely because the app itself is quitting (which
    /// shouldn't touch the list at all — it should still reflect what was
    /// open right before quitting).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppCoordinator.shared.isTerminating = true
        return .terminateNow
    }
}
