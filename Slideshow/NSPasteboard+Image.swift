//
//  NSPasteboard+Image.swift
//  Slideshow
//
//  Created by Paul Darcey on 28/8/2026.
//

import AppKit

extension NSPasteboard {
    /// Writes an image's file data plus its file URL together, so pasting
    /// works both as image data (into a Notes/Mail/Photos-style target)
    /// and as a file reference (into Finder or a file-accepting target).
    /// Shared by `SlideView`'s context menu and the app-level Cmd+C
    /// command, so "copy the currently displayed image" behaves
    /// identically no matter how it's triggered.
    func writeImage(at url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        clearContents()
        writeObjects([image, url as NSURL])
    }
}
