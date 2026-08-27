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
}
