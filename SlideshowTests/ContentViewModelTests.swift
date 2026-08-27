//
//  ContentViewModelTests.swift
//  SlideshowTests
//
//  Created by Paul Darcey on 27/8/2026.
//

import Testing
import AppKit
@testable import Slideshow

/// A class (not a struct) so `deinit` can clean up the temp directory each
/// test writes into. Swift Testing creates a fresh instance per @Test, so
/// each test gets its own isolated directory even when run in parallel.
@MainActor
final class ContentViewModelTests {
    let viewModel = ContentView.ViewModel()
    let tempDirectory: URL

    init() throws {
        // directoryHint must be explicit: appending(path:) otherwise infers
        // from the string alone (no trailing slash on a bare UUID), not
        // from the filesystem — unlike a real NSOpenPanel-vended URL, whose
        // hasDirectoryPath is always correct.
        tempDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    deinit {
        let directory = tempDirectory
        try? FileManager.default.removeItem(at: directory)
    }

    /// Writes a small, genuinely valid PNG file into `tempDirectory`.
    /// `getImagesAtURL` loads files through `NSImage(contentsOfFile:)`, so
    /// tests need real image data — not just arbitrary bytes with a `.png`
    /// extension — to exercise the same path production code does.
    private func writeTestImage(named name: String) throws {
        let size = NSSize(width: 2, height: 2)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        let tiffData = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiffData))
        let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: tempDirectory.appending(path: name))
    }

    // MARK: - parseSelectedURL

    @Test func parsingADirectoryURLReturnsItAsTheFolderWithNoSelectedImage() {
        let result = viewModel.parseSelectedURL(tempDirectory)
        #expect(result.folderURL == tempDirectory)
        #expect(result.selectedImage == nil)
    }

    @Test func parsingAFileURLReturnsItsParentAsTheFolderAndItselfAsTheSelectedImage() {
        let fileURL = tempDirectory.appending(path: "photo.png")
        let result = viewModel.parseSelectedURL(fileURL)
        #expect(result.folderURL == tempDirectory)
        #expect(result.selectedImage == fileURL)
    }

    // MARK: - getImagesAtURL

    @Test func loadingAFolderOfImagesSortsThemAlphabetically() throws {
        try writeTestImage(named: "c.png")
        try writeTestImage(named: "a.png")
        try writeTestImage(named: "b.png")

        viewModel.getImagesAtURL(tempDirectory)

        #expect(viewModel.images.map(\.imageName) == ["a.png", "b.png", "c.png"])
        #expect(viewModel.index == 0)
    }

    @Test func loadingAFolderIgnoresUnsupportedFileExtensions() throws {
        try writeTestImage(named: "photo.png")
        try "not an image".write(to: tempDirectory.appending(path: "notes.txt"), atomically: true, encoding: .utf8)

        viewModel.getImagesAtURL(tempDirectory)

        #expect(viewModel.images.map(\.imageName) == ["photo.png"])
    }

    @Test func loadingAnEmptyFolderProducesNoSlidesAndAZeroIndex() {
        viewModel.getImagesAtURL(tempDirectory)

        #expect(viewModel.images.isEmpty)
        #expect(viewModel.index == 0)
    }

    @Test func selectingASpecificFileSetsIndexToItsSortedPosition() throws {
        try writeTestImage(named: "a.png")
        try writeTestImage(named: "b.png")
        try writeTestImage(named: "c.png")
        let selected = tempDirectory.appending(path: "b.png")

        viewModel.getImagesAtURL(tempDirectory, selectedImage: selected)

        #expect(viewModel.index == 1)
    }

    @Test func selectingAFileNotInTheFolderFallsBackToTheFirstSlide() throws {
        try writeTestImage(named: "a.png")
        try writeTestImage(named: "b.png")
        let unrelatedFile = URL(fileURLWithPath: "/tmp/does-not-exist.png")

        viewModel.getImagesAtURL(tempDirectory, selectedImage: unrelatedFile)

        #expect(viewModel.index == 0)
    }

    @Test func reloadingASmallerFolderClampsAStaleIndexBackIntoBounds() throws {
        try writeTestImage(named: "a.png")
        try writeTestImage(named: "b.png")
        try writeTestImage(named: "c.png")
        viewModel.getImagesAtURL(tempDirectory, selectedImage: tempDirectory.appending(path: "c.png"))
        #expect(viewModel.index == 2)

        // Reload into an empty folder — index must not stay stale/out of
        // bounds (this also guards against a real infinite-recursion bug
        // caught during development, where clamping an already-clamped
        // index against an empty array recursed forever).
        let emptyDirectory = tempDirectory.appending(path: "empty")
        try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
        viewModel.getImagesAtURL(emptyDirectory)

        #expect(viewModel.images.isEmpty)
        #expect(viewModel.index == 0)
    }

    @Test func unreadableFolderSetsAccessDeniedAndProducesNoSlides() throws {
        // Simulates the sandboxed case where Finder hands the app a file
        // (e.g. via Open With) without access to its containing folder:
        // contentsOfDirectory fails. Rather than a silent, confusing
        // one-file "slideshow," this should be surfaced as an explicit
        // failure the picker screen can explain to the user.
        try writeTestImage(named: "photo.png")
        let selected = tempDirectory.appending(path: "photo.png")
        let unreadableFolder = tempDirectory.appending(path: "does-not-exist")

        viewModel.getImagesAtURL(unreadableFolder, selectedImage: selected)

        #expect(viewModel.images.isEmpty)
        #expect(viewModel.index == 0)
        #expect(viewModel.emptyReason == .accessDenied)
    }

    @Test func successfulLoadClearsAPreviousAccessDeniedState() throws {
        // emptyReason shouldn't stick at .accessDenied once a later load
        // actually succeeds.
        viewModel.getImagesAtURL(tempDirectory.appending(path: "does-not-exist"))
        #expect(viewModel.emptyReason == .accessDenied)

        try writeTestImage(named: "photo.png")
        viewModel.getImagesAtURL(tempDirectory)

        #expect(viewModel.images.map(\.imageName) == ["photo.png"])
    }

    @Test func readableFolderWithNoSupportedImagesSetsNoSupportedImagesReason() throws {
        try "not an image".write(to: tempDirectory.appending(path: "notes.txt"), atomically: true, encoding: .utf8)

        viewModel.getImagesAtURL(tempDirectory)

        #expect(viewModel.images.isEmpty)
        #expect(viewModel.emptyReason == .noSupportedImages)
    }

    @Test func freshViewModelStartsWithNotYetAttempted() {
        #expect(viewModel.images.isEmpty)
        #expect(viewModel.emptyReason == .notYetAttempted)
    }
}
