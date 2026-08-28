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
                SlideView(
                    slides: viewModel.images,
                    currentImage: startIndex,
                    slideshowIsRunning: $slideShowIsRunning,
                    onEnd: { lastDisplayedIndex in
                        viewModel.selectSlide(at: lastDisplayedIndex)
                    }
                )
            } else {
                DefaultView(
                    viewModel: viewModel,
                    onStartAtCurrent: startAtCurrent,
                    onRestartFromBeginning: restartFromBeginning
                )
            }
        }
        .navigationTitle(windowTitle)
        .focusedSceneValue(\.slideshowWindow, FocusedSlideshowWindow(
            viewModel: viewModel,
            isSlideshowRunning: slideShowIsRunning,
            startAtCurrent: startAtCurrent,
            restartFromBeginning: restartFromBeginning
        ))
        .onAppear {
            // Order matters: bootstrap/pending-consumption run before
            // onStateChanged is wired up and before captureWindowIfNeeded
            // registers this window, so the loads they trigger don't fire
            // a premature (and, worse, wipe-everything-out) persist before
            // this window is even in the registry to be counted correctly.
            AppCoordinator.shared.openWindowAction = openWindow
            let handledByBootstrap = AppCoordinator.shared.bootstrapLaunchIfNeeded(into: viewModel)
            // A freshly-opened window created for launch-time restoration of
            // a 2nd+ window picks up its target here — but only if bootstrap
            // didn't already handle *this* window directly (it queues
            // entries for additional windows, not for itself).
            if !handledByBootstrap, let state = AppCoordinator.shared.consumePendingOpen() {
                viewModel.resume(from: state)
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
            // itself once document types are registered — it creates a new
            // window and delivers the URL here, rather than ever reaching
            // AppDelegate.application(_:open:) (confirmed via testing; see
            // the note on AppDelegate). If another window was already
            // sitting empty, it's now redundant — close it rather than
            // leave it stranded.
            let (folderURL, selectedImage) = viewModel.parseSelectedURL(url)
            viewModel.getImagesAtURL(folderURL, selectedImage: selectedImage)
            if !viewModel.images.isEmpty {
                AppCoordinator.shared.closeEmptyWindows(excluding: viewModel)
            }
        }
    }

    /// This window's title: the loaded folder's name plus image count, so
    /// multiple open windows are distinguishable, or "Slideshow" before
    /// anything's been loaded.
    private var windowTitle: String {
        guard let folderName = viewModel.folderName else { return "Slideshow" }
        return "\(folderName) (\(viewModel.images.count.formatted()) images)"
    }

    /// Starts the slideshow at whatever image is currently selected on the
    /// picker screen. Shared by the "Start" button and the "Continue" menu
    /// command/shortcut, which are the same action.
    private func startAtCurrent() {
        startIndex = viewModel.index
        withAnimation {
            slideShowIsRunning = true
        }
    }

    /// Starts the slideshow from the first image, regardless of what's
    /// currently selected. Shared by the "Re-start from Beginning" button
    /// and its matching menu command/shortcut.
    private func restartFromBeginning() {
        startIndex = 0
        withAnimation {
            slideShowIsRunning = true
        }
    }

    /// Captures this view's own hosting window the first time it's known to
    /// be active, then registers it with `AppCoordinator` — same pattern
    /// `SlideView` uses for full-screen targeting, reused here so a
    /// specific window (not just "the app") can be tracked for persistence
    /// and for closing a now-redundant empty window elsewhere.
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
