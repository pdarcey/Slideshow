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

    mutating func selectedFileorFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
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
            do {
                let contents = try fileManager.contentsOfDirectory(at: selectedURL, includingPropertiesForKeys: [])
                let imageURLs = contents.filter({ $0.pathExtension == "jpg" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

                return imageURLs.first
            } catch {
                // Can't get contents of directory
                return nil
            }
        } else {
            return selectedURL
        }
    }

    func getImages(at selectedFileorFolder: URL) -> [Image] {
        let selectedFolder: URL
        if selectedFileorFolder.hasDirectoryPath {
            selectedFolder = selectedFileorFolder
        } else {
            selectedFolder = selectedFileorFolder.deletingLastPathComponent()
        }
        do {
            var images: [Image] = []
            let contents = try fileManager.contentsOfDirectory(at: selectedFolder, includingPropertiesForKeys: [])
            let imageURLs = contents.filter({ $0.pathExtension == "jpg" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            for url in imageURLs {
                guard let nsImage = NSImage(contentsOfFile: url.path) else { break }
                images.append(Image(nsImage: nsImage))
            }
            return images
        } catch {
            // Can't get contents of directory
            return []
        }
    }
}
