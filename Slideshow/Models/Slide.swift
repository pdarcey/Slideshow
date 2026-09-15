//
//  Slide.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import SwiftUI

/// A single slide in the slideshow: a source file, its filename, and a
/// stable identity independent of that filename.
///
/// Deliberately doesn't carry decoded image data itself — `ContentView.
/// ViewModel.loadedImage(for:)` decodes on demand instead, so memory use
/// doesn't scale with how many photos are in a folder (see `Journal.md`).
///
/// Driving `SlideView` from an array of these — rather than looking images
/// up by name in a `[String: Image]` dictionary — gives each photo genuine
/// SwiftUI view identity, which `.transition`/`.id`-based crossfade
/// animations need in order to actually trigger between slides.
struct Slide: Identifiable {
    let imageName: String
    /// The slide's source file — used both to decode its image on demand
    /// and for actions that need a real file reference rather than decoded
    /// content: copying to the pasteboard, revealing in Finder, sharing.
    let url: URL
    let id: UUID = UUID()
}
