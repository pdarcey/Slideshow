//
//  FileSystemReader.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

struct FileSystemReader {
    let fileManager = FileManager.default

    func selectFolder() -> [Image] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            guard let selectedFolder = panel.url else { return [] }
            return getImages(at: selectedFolder)
        }
        return []
    }

    private func getImages(at selectedFolder: URL) -> [Image] {
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
