//
//  SecurityScopedAccess.swift
//  Slideshow
//
//  Created by Paul Darcey on 15/9/2026.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.xerodonia.Slideshow", category: "SecurityScopedAccess")

/// Resolves a security-scoped bookmark and briefly re-opens access around a
/// unit of work, then closes it again immediately afterwards — the shared
/// shape behind every on-demand file access this sandboxed app needs once
/// its own initial Powerbox grant has expired (decoding a slide's image on
/// demand, or Copy/Share reading a file's raw bytes). Access is never held
/// any longer than `body`'s own execution; nothing here persists it.
///
/// Generalized out of what used to be `ContentView`'s private
/// `withFolderAccess(_:)` — Stage 15 (lazy slide loading) and Stage 16
/// (persisted granted-folder fallback) both need the same "resolve →
/// access → do work → release" shape `ContentView` already used for
/// Copy/Share.
enum SecurityScopedAccess {
    /// Runs `body` with security-scoped access to `bookmarkData` open, if
    /// resolution and access both succeed; `body` never runs otherwise.
    static func withAccess(to bookmarkData: Data, perform body: () -> Void) {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            logger.error("withAccess: failed to resolve bookmark data")
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            logger.error("withAccess: resolved \(url.path, privacy: .public) but startAccessingSecurityScopedResource() returned false")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        body()
    }
}
