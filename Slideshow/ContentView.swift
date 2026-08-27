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
    @Environment(\.appearsActive) private var appearsActive
    @State private var window: NSWindow?

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
        .onAppear {
            // Order matters: bootstrap/pending-consumption run before
            // onStateChanged is wired up and before captureWindowIfNeeded
            // registers this window, so the loads they trigger don't fire
            // a premature (and, worse, wipe-everything-out) persist before
            // this window is even in the registry to be counted correctly.
            AppCoordinator.shared.openWindowAction = openWindow
            let handledByBootstrap = AppCoordinator.shared.bootstrapLaunchIfNeeded(into: viewModel)
            // A freshly-opened window created for a Finder/Dock file-open
            // event, or for launch-time restoration of a 2nd+ window, picks
            // up its target here — but only if bootstrap didn't already
            // handle *this* window directly (it queues entries for
            // additional windows, not for itself).
            if !handledByBootstrap, let pending = AppCoordinator.shared.consumePendingOpen() {
                switch pending {
                case .url(let url):
                    let (folderURL, selectedImage) = viewModel.parseSelectedURL(url)
                    viewModel.getImagesAtURL(folderURL, selectedImage: selectedImage)
                case .restoredState(let state):
                    viewModel.resume(from: state)
                }
            }
            viewModel.onStateChanged = { AppCoordinator.shared.windowStateDidChange() }
            captureWindowIfNeeded()
        }
        .onChange(of: appearsActive) { _, _ in
            captureWindowIfNeeded()
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

    /// Captures this view's own hosting window the first time it's known to
    /// be active, then registers it with `AppCoordinator` — same pattern
    /// `SlideView` uses for full-screen targeting, reused here so a
    /// specific window (not just "the app") can be tracked for persistence
    /// and later reuse.
    private func captureWindowIfNeeded() {
        guard appearsActive, window == nil else { return }
        window = NSApplication.shared.keyWindow
        if let window {
            AppCoordinator.shared.register(viewModel, window: window)
            // Registration can lag behind the first successful load (e.g.
            // launch-time restore, which runs before appearsActive ever
            // flips true) — refresh here too so persistence never misses
            // this window.
            AppCoordinator.shared.windowStateDidChange()
        }
    }
}

#Preview {
    ContentView()
}
