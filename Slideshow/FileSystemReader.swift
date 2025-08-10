//
//  FileSystemReader.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

struct FileSystemReader {
    let fileManager: FileManager = FileManager.default
    var selectedURL: URL? = nil
    let supportedExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "heic", "tiff"]


    mutating func selectedFileorFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = "Start Slideshow"
        if panel.runModal() == .OK {
            guard let selectedFileorFolder = panel.url else { return nil }
            selectedURL = selectedFileorFolder
            return selectedFileorFolder
        }
        return nil
    }

    func selectedImageURL() -> URL? {
        guard let selectedURL else { return nil }
        if selectedURL.hasDirectoryPath {
            if let enumerator = fileManager.enumerator(at: selectedURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])  {
                var foundImages: [URL] = []

                for case let fileURL as URL in enumerator {
                    guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }

                    // Check that it's a regular file (not a directory or symlink)
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isAliasFileKey]),
                       resourceValues.isRegularFile == true {
                        foundImages.append(fileURL)
                    }
                }

                if !foundImages.isEmpty {
                    return foundImages.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first
                }
            }
            return nil
        } else {
            return selectedURL
        }
    }

    func getImages(at selectedFileorFolder: URL) -> [String: Image] {
        let selectedFolder: URL
        if selectedFileorFolder.hasDirectoryPath {
            selectedFolder = selectedFileorFolder
        } else {
            selectedFolder = selectedFileorFolder.deletingLastPathComponent()
        }
        var images: [String: Image] = [:]
        if let enumerator = fileManager.enumerator(at: selectedFolder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])  {
            var foundImageURLs: [URL] = []

            for case let fileURL as URL in enumerator {
                guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }

                // Check that it's a regular file (not a directory or symlink)
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isAliasFileKey]),
                   resourceValues.isRegularFile == true {
                    foundImageURLs.append(fileURL)
                }
            }
            for url in foundImageURLs {
                guard let nsImage = NSImage(contentsOfFile: url.path) else { break }
                images[url.lastPathComponent] = Image(nsImage: nsImage)
            }
        }
        return images
    }
}
