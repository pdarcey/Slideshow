//
//  ScrollWheelDetector.swift
//  Slideshow
//
//  Created by Paul Darcey on 10/8/2025.
//

import AppKit

class ScrollWheelDetector: NSView {
    var onScroll: ((CGFloat) -> Void)?

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
}
