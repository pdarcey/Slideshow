//
//  AppDelegate.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import AppKit

/// Note: `application(_:open:)` deliberately isn't implemented here.
/// Confirmed via testing (no `AppCoordinator` activity logged around a
/// Finder/Dock open) that SwiftUI's `WindowGroup` + `CFBundleDocumentTypes`
/// handles Finder/Dock file-open events itself — it creates and shows a new
/// window before this delegate ever gets a chance to intercept, delivering
/// the URL via `ContentView`'s `.onOpenURL` instead. See
/// `AppCoordinator.closeEmptyWindows(excluding:)` for how that path avoids
/// leaving a redundant empty window behind.
final class AppDelegate: NSObject, NSApplicationDelegate {
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
