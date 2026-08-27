//
//  ContentView.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = ContentView.ViewModel()
    @State private var slideShowIsRunning = false
    @State private var startIndex = 0

    var body: some View {
        ZStack {
            if slideShowIsRunning {
                SlideView(slides: viewModel.images, currentImage: startIndex, slideshowIsRunning: $slideShowIsRunning)
            } else {
                DefaultView(
                    viewModel: viewModel,
                    onStartAtCurrent: {
                        startIndex = viewModel.index
                        withAnimation {
                            slideShowIsRunning = true
                        }
                    },
                    onRestartFromBeginning: {
                        startIndex = 0
                        withAnimation {
                            slideShowIsRunning = true
                        }
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
