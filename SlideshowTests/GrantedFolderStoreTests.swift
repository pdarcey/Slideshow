//
//  GrantedFolderStoreTests.swift
//  SlideshowTests
//
//  Created by Paul Darcey on 15/9/2026.
//

import Testing
import Foundation
@testable import Slideshow

/// A class (not a struct) so `deinit` can tear down this test's isolated
/// `UserDefaults` suite and temp directory. Swift Testing creates a fresh
/// instance per @Test, so each test gets its own suite name — tests never
/// see each other's persisted bookmarks, and none of them ever touch the
/// app's real `UserDefaults`.
final class GrantedFolderStoreTests {
    let suiteName = "GrantedFolderStoreTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let tempDirectory: URL

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        tempDirectory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
        let directory = tempDirectory
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeSubdirectory(_ name: String, of parent: URL? = nil) throws -> URL {
        let url = (parent ?? tempDirectory).appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func bookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Resolves a stored bookmark back to a URL, so tests can prove
    /// *which* grant actually ended up covering a folder — not just that
    /// some bookmark did — without needing access to the store's private
    /// internals.
    private func resolvedURL(from bookmarkData: Data) throws -> URL {
        var isStale = false
        return try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    @Test func bookmarkCoveringReturnsNilForAnUngrantedFolder() throws {
        let folder = try makeSubdirectory("Documents")
        #expect(GrantedFolderStore.bookmarkCovering(folder, defaults: defaults) == nil)
    }

    @Test func recordingAFolderMakesItCoverItselfAndItsDescendants() throws {
        let root = try makeSubdirectory("Documents")
        let child = try makeSubdirectory("Images", of: root)
        GrantedFolderStore.record(root, bookmarkData: try bookmark(for: root), defaults: defaults)

        #expect(GrantedFolderStore.bookmarkCovering(root, defaults: defaults) != nil)
        #expect(GrantedFolderStore.bookmarkCovering(child, defaults: defaults) != nil)
    }

    @Test func recordingADescendantOfAnAlreadyGrantedFolderIsANoOp() throws {
        let root = try makeSubdirectory("Documents")
        let child = try makeSubdirectory("Images", of: root)
        GrantedFolderStore.record(root, bookmarkData: try bookmark(for: root), defaults: defaults)

        // Recording the already-covered child shouldn't replace the
        // higher-level grant with a narrower one.
        GrantedFolderStore.record(child, bookmarkData: try bookmark(for: child), defaults: defaults)

        let covering = try #require(GrantedFolderStore.bookmarkCovering(child, defaults: defaults))
        #expect(try resolvedURL(from: covering).standardizedFileURL.path == root.standardizedFileURL.path)
    }

    @Test func recordingAnAncestorReplacesAnExistingNarrowerGrant() throws {
        let root = try makeSubdirectory("Documents")
        let child = try makeSubdirectory("Images", of: root)
        GrantedFolderStore.record(child, bookmarkData: try bookmark(for: child), defaults: defaults)

        // Granting the ancestor afterwards should collapse the now-
        // redundant narrower grant into this higher one.
        GrantedFolderStore.record(root, bookmarkData: try bookmark(for: root), defaults: defaults)

        let covering = try #require(GrantedFolderStore.bookmarkCovering(child, defaults: defaults))
        #expect(try resolvedURL(from: covering).standardizedFileURL.path == root.standardizedFileURL.path)
    }

    @Test func recordingTwoUnrelatedFoldersKeepsBothIndependentlyCovered() throws {
        let folderA = try makeSubdirectory("Documents")
        let folderB = try makeSubdirectory("Pictures")
        GrantedFolderStore.record(folderA, bookmarkData: try bookmark(for: folderA), defaults: defaults)
        GrantedFolderStore.record(folderB, bookmarkData: try bookmark(for: folderB), defaults: defaults)

        #expect(GrantedFolderStore.bookmarkCovering(folderA, defaults: defaults) != nil)
        #expect(GrantedFolderStore.bookmarkCovering(folderB, defaults: defaults) != nil)

        let unrelated = try makeSubdirectory("Downloads")
        #expect(GrantedFolderStore.bookmarkCovering(unrelated, defaults: defaults) == nil)
    }

    @Test func bookmarkCoveringIgnoresABookmarkForADeletedFolder() throws {
        let vanishing = try makeSubdirectory("Vanishing")
        GrantedFolderStore.record(vanishing, bookmarkData: try bookmark(for: vanishing), defaults: defaults)
        try FileManager.default.removeItem(at: vanishing)

        #expect(GrantedFolderStore.bookmarkCovering(vanishing, defaults: defaults) == nil)
    }
}
