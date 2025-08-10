//
//  ContentView.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

struct ContentView: View {
    @State var slideShowIsRunning: Bool = false
    @State var images: [String: Image]? = nil
    @State private var startImageIndex: Int = 0

    var body: some View {
        ZStack {
            DefaultView(images: $images, slideshowRunning: $slideShowIsRunning, startImageIndex: $startImageIndex)
            if slideShowIsRunning && images != nil {
                SlideView(images: images ?? [:], currentImage: startImageIndex, slideshowIsRunning: $slideShowIsRunning)
                    .onAppear {
                        Task { @MainActor in NSApplication.shared.windows.last?.toggleFullScreen(nil) }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
