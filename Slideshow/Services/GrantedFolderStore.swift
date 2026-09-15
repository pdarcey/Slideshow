//
//  GrantedFolderStore.swift
//  Slideshow
//
//  Created by Paul Darcey on 15/9/2026.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.xerodonia.Slideshow", category: "GrantedFolderStore")

/// Persists security-scoped bookmarks for every folder the user has ever
/// been granted access to, independent of any single window — so a folder
/// granted in a *previous* session can still be used later, not just one
/// granted this session. `WindowStateStore` already restores open windows
/// across a relaunch; this is the same template, but deliberately never
/// pruned when a window closes.
///
/// The gap this closes: `NSOpenPanel` always works regardless of prior
/// grants, so it was never the problem. Dropping a single *file* onto an
/// existing window only grants access to that one file — enumerating its
/// parent folder fails unless the app already has broader access — and
/// until now "already has" only meant "already has this session."
/// `ContentView.ViewModel.getImagesAtURL` falls back to this store when
/// direct enumeration fails.
///
/// Deduplicated to the highest granted ancestor: recording a folder
/// already covered by a stored one is a no-op (access to a folder already
/// covers its whole subtree), and recording a folder that's itself an
/// ancestor of existing entries replaces them.
enum GrantedFolderStore {
    private static let key = "grantedFolders"

    /// Records `folderURL` as granted, deduplicated by ancestry against
    /// every previously-granted folder. Call this on every successful
    /// `getImagesAtURL` load, regardless of source (panel, drag, Dock/
    /// Finder, or `resume(from:)`) — `bookmarkData` must already have
    /// been created with active access to `folderURL` (or an ancestor of
    /// it) still open.
    static func record(_ folderURL: URL, bookmarkData: Data, defaults: UserDefaults = .standard) {
        var stored = resolveAll(pruningInvalidIn: defaults)

        guard !stored.contains(where: { isAncestor($0.url, of: folderURL) }) else {
            return // already covered by an existing grant
        }
        stored.removeAll { isAncestor(folderURL, of: $0.url) }
        stored.append((bookmarkData, folderURL))
        persist(stored.map(\.bookmarkData), defaults: defaults)
    }

    /// The bookmark of a previously-granted folder that contains `url`, if
    /// any — used as a fallback when direct access to `url` just failed.
    /// Bookmarks that fail to resolve (folder deleted, or access revoked
    /// via System Settings → Privacy & Security → Files and Folders) are
    /// pruned from the store as a side effect of resolving them here.
    static func bookmarkCovering(_ url: URL, defaults: UserDefaults = .standard) -> Data? {
        let candidates = resolveAll(pruningInvalidIn: defaults)
        let match = candidates.first { isAncestor($0.url, of: url) }
        logger.info(
            """
            bookmarkCovering(\(url.path, privacy: .public)): \(candidates.count) stored, \
            match=\(match?.url.path ?? "none", privacy: .public)
            """
        )
        return match?.bookmarkData
    }

    /// True if `ancestor` is `descendant` itself or one of its parent
    /// directories, compared via resolved, standardized path components —
    /// not raw bookmark bytes or a string prefix (which would wrongly
    /// match `~/Documents2` against `~/Documents`).
    private static func isAncestor(_ ancestor: URL, of descendant: URL) -> Bool {
        let ancestorParts = ancestor.standardizedFileURL.pathComponents
        let descendantParts = descendant.standardizedFileURL.pathComponents
        guard ancestorParts.count <= descendantParts.count else { return false }
        return Array(descendantParts.prefix(ancestorParts.count)) == ancestorParts
    }

    /// Resolves every stored bookmark to its current URL, dropping (and
    /// re-persisting without) any that fail to resolve.
    private static func resolveAll(pruningInvalidIn defaults: UserDefaults) -> [(bookmarkData: Data, url: URL)] {
        let stored = load(from: defaults)
        var resolved: [(bookmarkData: Data, url: URL)] = []
        for bookmarkData in stored {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                logger.error("resolveAll: a stored bookmark failed to resolve and is being pruned")
                continue
            }
            resolved.append((bookmarkData, url))
        }
        if resolved.count != stored.count {
            logger.info("resolveAll: pruned \(stored.count - resolved.count) unresolvable bookmark(s)")
            persist(resolved.map(\.bookmarkData), defaults: defaults)
        }
        return resolved
    }

    private static func load(from defaults: UserDefaults) -> [Data] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([Data].self, from: data)
        } catch {
            logger.error("Failed to decode persisted granted folders: \(error)")
            return []
        }
    }

    private static func persist(_ bookmarks: [Data], defaults: UserDefaults) {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            defaults.set(data, forKey: key)
        } catch {
            logger.error("Failed to encode granted folders for persistence: \(error)")
        }
    }
}
