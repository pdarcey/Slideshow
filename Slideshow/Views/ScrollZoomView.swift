//
//  ScrollZoomView.swift
//  Slideshow
//
//  Created by Paul Darcey on 10/8/2025.
//

import SwiftUI

struct ScrollZoomView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    var onMagnify: (CGFloat) -> Void = { _ in }

    func makeNSView(context: Context) -> ZoomGestureDetector {
        let view = ZoomGestureDetector()
        view.onScroll = onScroll
        view.onMagnify = onMagnify
        return view
    }

    func updateNSView(_ nsView: ZoomGestureDetector, context: Context) {
        nsView.onScroll = onScroll
        nsView.onMagnify = onMagnify
    }
}

// MARK: - Previews

#Preview {
    ScrollZoomView(onScroll: { _ in })
}
