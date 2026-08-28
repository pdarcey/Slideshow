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
            return images[index].image
        }

        private static let supportedExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"]

        /// Displays the file/folder chooser and loads whatever was picked.
        func selectFileOrFolder() {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.bmp, .jpeg, .png, .tiff, .gif, .heic]
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
        /// separately granted earlier in this launch. This is a hard macOS
        /// sandbox restriction, not something worth working around (Finder's
        /// "Open With"/double-click hand the app exactly one file with no
        /// way to ask for its folder, which is why Slideshow no longer
        /// registers as a handler for individual image files — only for
        /// folders). Rather than showing a silent, confusing one-file
        /// "slideshow" when a lone file does still reach here, surface it
        /// via `emptyReason` so the picker screen can explain what happened.
        func getImagesAtURL(_ folderURL: URL, selectedImage: URL? = nil) {
            let fileManager = FileManager.default

            guard let files = try? fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil
            ) else {
                images = []
                index = 0
                bookmarkData = nil
                folderName = nil
                emptyReason = .accessDenied
                onStateChanged?()
                return
            }

            let sortedImages = files
                .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            var loadedSlides: [Slide] = []
            for url in sortedImages {
                guard let nsImage = NSImage(contentsOfFile: url.path) else { break }
                loadedSlides.append(Slide(imageName: url.lastPathComponent, image: Image(nsImage: nsImage)))
            }

            images = loadedSlides
            if loadedSlides.isEmpty {
                emptyReason = .noSupportedImages
                bookmarkData = nil
                folderName = nil
            } else {
                folderName = folderURL.lastPathComponent
                // Refreshed on every successful load, regardless of whether
                // folderURL came from a fresh Powerbox grant or a resolved
                // bookmark (resume(from:)) — this is what keeps a resumed
                // window's stored bookmark from ever going stale.
                bookmarkData = try? folderURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
            if let selectedImage, let startIndex = sortedImages.firstIndex(of: selectedImage) {
                index = startIndex
            } else {
                index = 0
            }
            onStateChanged?()
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
