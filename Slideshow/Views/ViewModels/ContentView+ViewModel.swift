//
//  ContentView+ViewModel.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.xerodonia.Slideshow", category: "ContentView.ViewModel")

extension ContentView {
    /// Owns loading and selection state for the picker screen: which folder
    /// was chosen, the resulting slides, and which one is currently
    /// selected. Kept separate from `DefaultView` so this logic is testable
    /// independent of the view hierarchy.
    @Observable
    @MainActor
    final class ViewModel {
        /// Why `images` is currently empty, so `DefaultView` can tell the
        /// user what actually happened instead of always showing the same
        /// generic "nothing chosen yet" prompt.
        enum EmptyReason: Equatable {
            case notYetAttempted
            case accessDenied
            case noSupportedImages
            case previousFolderUnavailable
        }

        private(set) var images: [Slide] = []
        private(set) var emptyReason: EmptyReason = .notYetAttempted

        /// The loaded folder's name, so the window title can show which
        /// folder this window is displaying. Nil whenever `images` is empty.
        private(set) var folderName: String?

        /// The loaded folder's URL, so the window can set its represented
        /// URL (`.navigationDocument`) — gives the standard right-click/
        /// Cmd-click title bar path popup for free. Nil whenever `images`
        /// is empty, same as `folderName`.
        private(set) var folderURL: URL?

        /// A security-scoped bookmark for the currently-loaded folder, so
        /// this window's state can be persisted and restored across a
        /// relaunch. Refreshed on every successful load; nil whenever
        /// `images` is empty.
        private(set) var bookmarkData: Data?

        /// Set once by `ContentView` after this view model is created, so a
        /// successful load can notify `AppCoordinator` to persist the
        /// current set of open windows. A plain closure rather than a
        /// direct `AppCoordinator` reference keeps this class free of any
        /// app-lifecycle coupling, so it stays fully testable in isolation
        /// (tests never set this, so it's simply never called).
        var onStateChanged: (() -> Void)?

        /// Looks up a previously-granted folder covering a URL that direct
        /// enumeration just failed for (see `GrantedFolderStore`). Nil by
        /// default, same reasoning as `onStateChanged`: tests never set
        /// this, so it's simply never called, and never touches real
        /// `UserDefaults`. `ContentView` wires it to `GrantedFolderStore`.
        var grantedFolderLookup: ((URL) -> Data?)?

        /// Records a freshly-granted folder as available for future
        /// sessions. Same testability reasoning as `grantedFolderLookup`.
        var recordGrantedFolder: ((URL, Data) -> Void)?

        private(set) var index: Int = 0 {
            didSet {
                let clamped = images.isEmpty ? 0 : min(max(index, 0), images.count - 1)
                // Guard against reassigning the same value: didSet still
                // fires on a same-value assignment, so without this check
                // clamping an already-clamped index (e.g. 0 while images is
                // empty) would recurse forever.
                if clamped != index {
                    index = clamped
                }
            }
        }

        /// The slide currently selected — the hero image shown on the
        /// picker screen, and the slide "Start" will begin the show on.
        /// Computed from `index` rather than stored separately, so there's
        /// only ever one load of a given file's image data.
        var selectedImage: Image {
            guard images.indices.contains(index) else {
                return Image(systemName: "photo.on.rectangle")
            }
            return loadedImage(for: images[index])
        }

        /// Decoded images for whichever slides were most recently
        /// requested, oldest-first. Bounded to `maxCachedImages` regardless
        /// of folder size — trimmed on every insert — so memory use stays
        /// flat rather than scaling with how many photos are in the
        /// loaded folder. Two is enough to cover a crossfade's momentary
        /// overlap between the outgoing and incoming slide without holding
        /// anything beyond that.
        private var imageCache: [(id: UUID, image: Image)] = []
        private let maxCachedImages = 2

        private static let supportedExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"]

        /// Decodes `slide`'s image on demand, re-opening security-scoped
        /// access to this window's folder for just long enough to read it
        /// (the original access `getImagesAtURL` had is long since closed
        /// by the time a slide is actually displayed). Caches the result —
        /// see `imageCache` — so navigating back to a recently-shown slide
        /// doesn't re-decode it.
        func loadedImage(for slide: Slide) -> Image {
            if let cached = imageCache.first(where: { $0.id == slide.id })?.image {
                return cached
            }
            var decoded: Image?
            if let bookmarkData {
                SecurityScopedAccess.withAccess(to: bookmarkData) {
                    decoded = NSImage(contentsOfFile: slide.url.path).map(Image.init(nsImage:))
                }
            }
            let resolved = decoded ?? Image(systemName: "photo.on.rectangle")
            cache(resolved, for: slide.id)
            return resolved
        }

        private func cache(_ image: Image, for id: UUID) {
            imageCache.removeAll { $0.id == id }
            imageCache.append((id, image))
            if imageCache.count > maxCachedImages {
                imageCache.removeFirst(imageCache.count - maxCachedImages)
            }
        }

        /// Displays the file/folder chooser and loads whatever was picked.
        func selectFileOrFolder() {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = true
            // .folder has to be listed alongside the image types, even
            // though canChooseDirectories is already true — otherwise a
            // folder doesn't conform to anything in allowedContentTypes,
            // so the panel lets you navigate into one but never actually
            // select it; only images are selectable without this.
            panel.allowedContentTypes = [.bmp, .jpeg, .png, .tiff, .gif, .heic, .folder]
            panel.allowsMultipleSelection = false
            panel.prompt = "Select"
            // Picking a single image (rather than its folder) works fine —
            // parseSelectedURL/getImagesAtURL already resolve it to that
            // image's position within its folder — but nothing else here
            // hints that's an option, so spell it out.
            panel.message = "Choose a folder of images, or a single image to start on."

            if panel.runModal() == .OK, let selection = panel.url {
                let (folderURL, selectedImage) = parseSelectedURL(selection)
                getImagesAtURL(folderURL, selectedImage: selectedImage)
            }
        }

        /// Splits a picked/dropped URL into the folder to load and, if a
        /// specific file (rather than a folder) was picked, that file.
        func parseSelectedURL(_ url: URL) -> (folderURL: URL, selectedImage: URL?) {
            let folderURL: URL
            var selectedImage: URL?
            if url.hasDirectoryPath {
                folderURL = url
            } else {
                folderURL = url.deletingLastPathComponent()
                selectedImage = url
            }
            return (folderURL, selectedImage)
        }

        /// Loads every supported image directly inside `folderURL`, sorted
        /// alphabetically, and selects `selectedImage`'s position within
        /// that sorted list if one was given (otherwise the first slide).
        ///
        /// The app is sandboxed with only user-selected read access. Picking
        /// or dropping a *folder* (via `selectFileOrFolder()`, in-app
        /// drag-and-drop, or dropping a folder on the Dock icon) grants
        /// access to its whole tree, but picking or dropping a single
        /// *file* only grants access to that one file — enumerating its
        /// *parent* folder fails unless broader access was already
        /// separately granted earlier. Until now "already granted" only
        /// ever meant "granted earlier this launch"; `grantedFolderLookup`
        /// (see `GrantedFolderStore`) extends that to a folder granted in
        /// a *previous* session too, as a fallback once direct enumeration
        /// fails. Finder's "Open With"/double-click hand the app exactly
        /// one file with no way to ask for its folder at all, which is why
        /// Slideshow no longer registers as a handler for individual image
        /// files — only for folders — so this fallback matters specifically
        /// for drag-and-drop of a lone file. Rather than showing a silent,
        /// confusing one-file "slideshow" when access still isn't
        /// available, surface it via `emptyReason` so the picker screen
        /// can explain what happened.
        func getImagesAtURL(_ folderURL: URL, selectedImage: URL? = nil) {
            // A new folder invalidates every cached decode from whichever
            // one was loaded before, on every outcome below (success or
            // not) — otherwise switching folders in an existing window
            // would keep accumulating stale entries from earlier ones.
            imageCache.removeAll()

            let fileManager = FileManager.default
            var files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            var newBookmarkData: Data?

            if files != nil {
                // Direct/ambient access already covers this (a fresh
                // Powerbox grant from a panel pick, drag, or Dock/Finder
                // open, or a resume(from:) bookmark's own still-open
                // access window) — refreshed on every successful load, so
                // a resumed window's stored bookmark never goes stale.
                newBookmarkData = try? folderURL.bookmarkData(
                    options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil
                )
            } else if let coveringBookmark = grantedFolderLookup?(folderURL) {
                // Direct enumeration failed — retry under a previously-
                // granted ancestor folder's access, which covers
                // folderURL's whole subtree, bookmark creation included.
                SecurityScopedAccess.withAccess(to: coveringBookmark) {
                    files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                    if files != nil {
                        newBookmarkData = try? folderURL.bookmarkData(
                            options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil
                        )
                    }
                }
            }

            guard let files else {
                images = []
                index = 0
                clearFolderState(emptyReason: .accessDenied)
                onStateChanged?()
                return
            }

            // Images are decoded on demand (loadedImage(for:)), not here —
            // so this is a plain extension-based filter, not a validity
            // check. A file with a supported extension that turns out not
            // to actually decode later just falls back to the placeholder
            // icon at display time, same as any other decode failure.
            let loadedSlides = files
                .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .map { Slide(imageName: $0.lastPathComponent, url: $0) }

            images = loadedSlides
            if loadedSlides.isEmpty {
                clearFolderState(emptyReason: .noSupportedImages)
            } else {
                folderName = folderURL.lastPathComponent
                self.folderURL = folderURL
                bookmarkData = newBookmarkData
                if let bookmarkData {
                    recordGrantedFolder?(folderURL, bookmarkData)
                }
            }
            if let selectedImage, let startIndex = loadedSlides.firstIndex(where: { $0.url == selectedImage }) {
                index = startIndex
            } else {
                index = 0
            }
            onStateChanged?()
        }

        /// Clears everything about the previously-loaded folder except
        /// `images`/`index` (each call site's own outcome dictates those
        /// slightly differently) — shared by `getImagesAtURL`'s two
        /// "nothing usable" outcomes (no access, no supported images).
        private func clearFolderState(emptyReason: EmptyReason) {
            bookmarkData = nil
            folderName = nil
            folderURL = nil
            self.emptyReason = emptyReason
        }

        /// Updates which slide is "selected" without reloading anything —
        /// used when a slideshow ends, so the picker screen's hero image
        /// reflects wherever the user left off rather than resetting to
        /// whatever was selected before the slideshow started. Notifies
        /// `onStateChanged` so this survives a quit/relaunch, the same as
        /// every other change to the persisted selection.
        func selectSlide(at newIndex: Int) {
            index = newIndex
            onStateChanged?()
        }

        /// This window's current state for persistence, or nil if there's
        /// nothing worth restoring (no folder loaded).
        func currentWindowState() -> WindowState? {
            guard !images.isEmpty, let bookmarkData else { return nil }
            return WindowState(bookmarkData: bookmarkData, selectedImageName: images[index].imageName)
        }

        /// Restores a previously-persisted folder + selected image, resolving
        /// its security-scoped bookmark. Access is only needed for the
        /// duration of this call — `getImagesAtURL` loads every image
        /// eagerly into memory before returning — so it's started and
        /// immediately paired with a `defer`-based stop, matching Apple's
        /// own sample pattern, rather than tracked as persistent state.
        func resume(from state: WindowState) {
            var isStale = false
            var resolveError: Error?
            let resolvedURL: URL?
            do {
                resolvedURL = try URL(
                    resolvingBookmarkData: state.bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
            } catch {
                resolvedURL = nil
                resolveError = error
            }
            guard let url = resolvedURL else {
                logger.error("resume(from:) failed to resolve bookmark: \(resolveError.debugDescription, privacy: .public)")
                images = []
                index = 0
                bookmarkData = nil
                folderName = nil
                self.folderURL = nil
                emptyReason = .previousFolderUnavailable
                onStateChanged?()
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                logger.error("resume(from:) resolved \(url.path, privacy: .public) but startAccessingSecurityScopedResource() returned false")
                images = []
                index = 0
                bookmarkData = nil
                folderName = nil
                self.folderURL = nil
                emptyReason = .previousFolderUnavailable
                onStateChanged?()
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            logger.info("resume(from:) resolved \(url.path, privacy: .public), isStale=\(isStale), selectedImageName=\(state.selectedImageName ?? "nil", privacy: .public)")

            let selectedImage = state.selectedImageName.map { url.appending(path: $0) }
            getImagesAtURL(url, selectedImage: selectedImage)
            logger.info("resume(from:) finished with \(self.images.count) images, emptyReason=\(String(describing: self.emptyReason), privacy: .public)")
        }
    }
}
