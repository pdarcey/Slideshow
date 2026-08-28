//
//  WindowState.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import Foundation

/// Everything needed to restore one window across a relaunch: which folder
/// (as a security-scoped bookmark, since a sandboxed app can't just keep a
/// plain path) and which image within it was selected.
struct WindowState: Codable, Hashable {
    var bookmarkData: Data
    var selectedImageName: String?
}
