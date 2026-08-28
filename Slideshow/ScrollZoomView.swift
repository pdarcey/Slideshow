//
//  ScrollZoomView.swift
//  Slideshow
//
//  Created by Paul Darcey on 10/8/2025.
//

import SwiftUI

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

// MARK: - Previews

#Preview {
    ScrollZoomView(onScroll: { _ in })
}
