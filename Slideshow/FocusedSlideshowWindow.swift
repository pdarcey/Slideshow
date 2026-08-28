//
//  FocusedSlideshowWindow.swift
//  Slideshow
//
//  Created by Paul Darcey on 28/8/2026.
//

import SwiftUI

/// What the frontmost `ContentView` exposes to app-level `.commands`, which
/// live outside the view hierarchy and so can't reach a window's own
/// `@State`/view model directly. Set via `.focusedSceneValue(\.slideshowWindow:)`
/// in `ContentView`, read via `@FocusedValue(\.slideshowWindow)` in
/// `SlideshowApp`.
@MainActor
struct FocusedSlideshowWindow {
    var viewModel: ContentView.ViewModel
    var isSlideshowRunning: Bool
    var startAtCurrent: () -> Void
    var restartFromBeginning: () -> Void
    /// Toggles the in-slideshow Help overlay (`?`).
    var toggleHelp: () -> Void
    /// Resets zoom/pan to their defaults (`=`).
    var resetZoom: () -> Void
    /// Copies the currently displayed slide's image + file URL to the
    /// pasteboard (Cmd+C).
    var copyImage: () -> Void

    /// Whether "Continue"/"Re-start from Beginning" have anything to act
    /// on — matches the same condition `DefaultView` uses to show its
    /// "Start"/"Re-start from Beginning" buttons in the first place.
    var canStartSlideshow: Bool {
        !viewModel.images.isEmpty && !isSlideshowRunning
    }
}

private struct FocusedSlideshowWindowKey: FocusedValueKey {
    typealias Value = FocusedSlideshowWindow
}

extension FocusedValues {
    var slideshowWindow: FocusedSlideshowWindow? {
        get { self[FocusedSlideshowWindowKey.self] }
        set { self[FocusedSlideshowWindowKey.self] = newValue }
    }
}
