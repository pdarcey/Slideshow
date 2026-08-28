//
//  ZoomGestureDetector.swift
//  Slideshow
//
//  Created by Paul Darcey on 10/8/2025.
//

import AppKit

/// Bridges the two trackpad/mouse zoom gestures AppKit delivers as raw
/// `NSEvent`s that SwiftUI has no native equivalent for: two-finger scroll
/// and pinch-to-magnify. Both report an incremental delta per event (not an
/// absolute value), so callers accumulate them the same way.
///
/// This view has to sit on top of the whole slide area to receive these
/// events at all — which means it also intercepts events SwiftUI gesture
/// recognizers on views underneath it never see. A `MagnifyGesture`
/// attached to the image below this view was tried first and silently did
/// nothing, for exactly that reason; overriding `magnify(with:)` here,
/// alongside the existing `scrollWheel(with:)` override, was the fix.
class ZoomGestureDetector: NSView {
    var onScroll: ((CGFloat) -> Void)?
    var onMagnify: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)

        let delta: CGFloat
        if event.hasPreciseScrollingDeltas {
            delta = event.scrollingDeltaY
        } else {
            delta = event.scrollingDeltaY * 0.1 // scale up for mouse wheels if needed
        }

        onScroll?(delta)
    }

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        onMagnify?(event.magnification)
    }

    /// Right-clicks are declined outright (returns `nil`), rather than
    /// handled with another `on...` callback like scroll/magnify: SwiftUI's
    /// `.contextMenu` is resolved through this same classic
    /// `rightMouseDown`/`menu(for:)` hit-testing path, unlike `.gesture()`/
    /// `.onTapGesture()` (tap-to-advance, drag-to-pan), which apparently
    /// aren't blocked by this view sitting on top and already work fine
    /// without any override here. Declining lets AppKit's hit-test
    /// continue past this view to the `.contextMenu` on the slide image
    /// underneath, instead of silently swallowing the right-click the same
    /// way it silently swallowed magnify events before that override
    /// existed.
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let event = NSApp.currentEvent, event.type == .rightMouseDown || event.type == .rightMouseUp {
            return nil
        }
        return super.hitTest(point)
    }
}
