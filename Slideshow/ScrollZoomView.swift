//
//  ScrollZoomView.swift
//  Slideshow
//
//  Created by Paul Darcey on 10/8/2025.
//

import SwiftUI
import AppKit

class ScrollWheelDetector: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)

        let delta: CGFloat
        if event.hasPreciseScrollingDeltas {
            delta = event.scrollingDeltaY
        } else {
            delta = event.scrollingDeltaY * 1 // scale up for mouse wheels if needed
        }

        onScroll?(delta)
    }
}

struct ScrollZoomView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelDetector {
        let view = ScrollWheelDetector()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelDetector, context: Context) {
        nsView.onScroll = onScroll
    }
}
#Preview {
    ScrollZoomView(onScroll: { _ in })
}
