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
    @Environment(\.openWindow) private var openWindow

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
        .task {
            AppCoordinator.shared.openWindowAction = openWindow
        }
        .onAppear {
            AppCoordinator.shared.register(viewModel)
            // A freshly-opened window created for a Finder/Dock file-open
            // event picks up its target here.
            if let pending = AppCoordinator.shared.pendingURL {
                AppCoordinator.shared.pendingURL = nil
                let (folderURL, selectedImage) = viewModel.parseSelectedURL(pending)
                viewModel.getImagesAtURL(folderURL, selectedImage: selectedImage)
            }
        }
        .onDisappear {
            AppCoordinator.shared.unregister(viewModel)
        }
        .onOpenURL { url in
            // SwiftUI's WindowGroup handles Finder/Dock file-open events
            // itself once document types are registered — it creates (or
            // routes to) a window and delivers the URL here, rather than
            // ever reaching AppDelegate.application(_:open:).
            let (folderURL, selectedImage) = viewModel.parseSelectedURL(url)
            viewModel.getImagesAtURL(folderURL, selectedImage: selectedImage)
        }
    }
}

#Preview {
    ContentView()
}
