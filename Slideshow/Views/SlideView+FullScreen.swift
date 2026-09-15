//
//  SlideView+FullScreen.swift
//  Slideshow
//
//  Created by Paul Darcey on 15/9/2026.
//

import SwiftUI

extension SlideView {
    /// Captures this view's own hosting window the first time it's known to
    /// be active, then enters full screen. Using `appearsActive` rather than
    /// `NSApplication.shared.windows.last`/`.keyWindow` means this reliably
    /// targets *this* SlideView's window even when other Slideshow windows
    /// are open at the same time. Also starts `cursorIdleHider` watching
    /// this window, so idle-hide tracks whichever window this slideshow is
    /// actually showing in.
    func captureWindowIfNeeded() {
        guard appearsActive, window == nil else { return }
        window = NSApplication.shared.keyWindow
        if let window {
            cursorIdleHider.start(watching: window)
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
    }

    func exitFullScreen() {
        // Toggle off full-screen mode, if necessary
        guard let window, window.styleMask.contains(.fullScreen) else { return }
        Task { @MainActor in
            window.toggleFullScreen(nil)
        }
    }
}
