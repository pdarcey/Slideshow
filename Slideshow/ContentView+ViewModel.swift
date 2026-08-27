//
//  ContentView+ViewModel.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import SwiftUI

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
        }

        private(set) var images: [Slide] = []
        private(set) var emptyReason: EmptyReason = .notYetAttempted

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
            panel.prompt = "Start Slideshow"

            if panel.runModal() == .OK, let selection = panel.url {
                let (folderURL, selectedImage) = parseSelectedURL(selection)
                getImagesAtURL(folderURL, selectedImage: selectedImage)
            }
        }

        /// Splits a picked/dropped URL into the folder to load and, if a
        /// specific file (rather than a folder) was picked, that file.
        func parseSelectedURL(_ url: URL) -> (folderURL: URL, selectedImage: URL?) {
            let folderURL: URL
            var selectedImage: URL? = nil
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

            guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
                images = []
                index = 0
                emptyReason = .accessDenied
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
            }
            if let selectedImage, let startIndex = sortedImages.firstIndex(of: selectedImage) {
                index = startIndex
            } else {
                index = 0
            }
        }
    }
}
