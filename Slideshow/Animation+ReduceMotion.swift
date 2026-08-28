//
//  Animation+ReduceMotion.swift
//  Slideshow
//
//  Created by Paul Darcey on 28/8/2026.
//

import SwiftUI

/// A drop-in replacement for `withAnimation(_:_:)` that runs `body`
/// unanimated when Reduce Motion is on, rather than always animating.
/// `reduceMotion` isn't read implicitly (a free function has no
/// `@Environment` access) — pass the caller's own
/// `@Environment(\.accessibilityReduceMotion)` value in explicitly.
@MainActor
func withOptionalAnimation<Result>(
    _ animation: Animation? = .default,
    reduceMotion: Bool,
    _ body: () throws -> Result
) rethrows -> Result {
    if reduceMotion {
        return try body()
    }
    return try withAnimation(animation, body)
}
