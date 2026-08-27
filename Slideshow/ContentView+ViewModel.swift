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
        private(set) var images: [Slide] = []

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
        func getImagesAtURL(_ folderURL: URL, selectedImage: URL? = nil) {
            let fileManager = FileManager.default

            guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
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
            if let selectedImage, let startIndex = sortedImages.firstIndex(of: selectedImage) {
                index = startIndex
            } else {
                index = 0
            }
        }
    }
}
