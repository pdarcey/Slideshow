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

    var body: some View {
        ZStack {
            DefaultView(images: $images, slideshowRunning: $slideShowIsRunning)
            if slideShowIsRunning {
                SlideView(images: images ?? [:], currentImage: 0, slideshowIsRunning: $slideShowIsRunning)
            }
        }

    }
}

#Preview {
    ContentView()
}
