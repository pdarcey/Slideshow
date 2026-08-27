//
//  Slide.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import SwiftUI

/// A single slide in the slideshow: an image, its source filename, and a
/// stable identity independent of that filename.
///
/// Driving `SlideView` from an array of these — rather than looking images
/// up by name in a `[String: Image]` dictionary — gives each photo genuine
/// SwiftUI view identity, which `.transition`/`.id`-based crossfade
/// animations need in order to actually trigger between slides.
struct Slide: Identifiable {
    let imageName: String
    let image: Image
    let id: UUID = UUID()
}
