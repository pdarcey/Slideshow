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
    /// These four are owned here, not by `SlideView`, so app-level
    /// `.commands` (which live outside the view hierarchy and can't reach
    /// a window's local `@State` directly) can read/drive them via
    /// `FocusedSlideshowWindow` — see that type and `SlideshowApp`.
    @State private var currentImageIndex = 0
    @State private var showHelp = false
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @Environment(\.openWindow) private var openWindow
    @Environment(\.appearsActive) private var appearsActive
    @State private var window: NSWindow?
    /// Shared between `DefaultView`'s hero image and `SlideView`'s current
    /// slide, so starting/ending a slideshow morphs the photo between the
    /// two rather than just cutting or crossfading. Only ever one of the
    /// two views carrying this id exists at a time (they're mutually
    /// exclusive branches below), so it has no effect on ordinary
    /// slide-to-slide navigation within a running slideshow — only on the
    /// moment this ZStack swaps between the two branches.
    @Namespace private var heroNamespace

    var body: some View {
        ZStack {
            if slideShowIsRunning {
                SlideView(
                    slides: viewModel.images,
                    currentImage: $currentImageIndex,
                    slideshowIsRunning: $slideShowIsRunning,
                    showHelp: $showHelp,
                    scale: $scale,
                    offset: $offset,
                    namespace: heroNamespace,
                    onCopyImage: copyImage,
                    shareableURL: shareableCopy,
                    onEnd: { lastDisplayedIndex in
                        viewModel.selectSlide(at: lastDisplayedIndex)
                    }
                )
            } else {
                DefaultView(
                    viewModel: viewModel,
                    namespace: heroNamespace,
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
            restartFromBeginning: restartFromBeginning,
            toggleHelp: { showHelp.toggle() },
            resetZoom: {
                withAnimation {
                    scale = 1
                    offset = .zero
                }
            },
            copyImage: copyCurrentImage
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
        beginSlideshow(at: viewModel.index)
    }

    /// Starts the slideshow from the first image, regardless of what's
    /// currently selected. Shared by the "Re-start from Beginning" button
    /// and its matching menu command/shortcut.
    private func restartFromBeginning() {
        beginSlideshow(at: 0)
    }

    /// Shared by `startAtCurrent()`/`restartFromBeginning()`: resets
    /// zoom/pan/Help to their defaults before showing `SlideView` — since
    /// that state now lives here rather than in `SlideView` itself, it no
    /// longer resets for free just by that view being torn down and
    /// recreated each time a slideshow starts.
    private func beginSlideshow(at index: Int) {
        currentImageIndex = index
        scale = 1
        offset = .zero
        showHelp = false
        withAnimation {
            slideShowIsRunning = true
        }
    }

    /// Copies the currently displayed slide's image + file URL to the
    /// pasteboard. Backs both the app-level Cmd+C command (via
    /// `FocusedSlideshowWindow`) and `SlideView`'s own context-menu "Copy
    /// Image" (passed down as a closure, rather than `SlideView` writing
    /// to the pasteboard directly) — both need `withFolderAccess` below,
    /// which only `ContentView` can provide via `viewModel.bookmarkData`.
    private func copyCurrentImage() {
        guard viewModel.images.indices.contains(currentImageIndex) else { return }
        copyImage(viewModel.images[currentImageIndex].url)
    }

    /// As `copyCurrentImage()`, but for an arbitrary slide URL — what
    /// `SlideView`'s context menu actually calls, since it already has
    /// the specific slide in scope there.
    private func copyImage(_ url: URL) {
        withFolderAccess {
            NSPasteboard.general.writeImage(at: url)
        }
    }

    /// A safe-to-share copy of a slide's image, in the temp directory
    /// (always accessible, no security scoping needed). `ShareLink`'s
    /// Share Sheet lifetime is indeterminate and asynchronous — far
    /// longer than `withFolderAccess`'s synchronous access window could
    /// ever cover — so sharing the original file's URL directly isn't an
    /// option for a folder whose access came from a resolved bookmark.
    /// Falls back to the original URL if the copy fails for any reason.
    private func shareableCopy(of url: URL) -> URL {
        var result = url
        withFolderAccess {
            guard let data = try? Data(contentsOf: url) else { return }
            let candidate = URL.temporaryDirectory.appending(path: url.lastPathComponent)
            if (try? data.write(to: candidate)) != nil {
                result = candidate
            }
        }
        return result
    }

    /// Re-resolves the loaded folder's bookmark and briefly re-opens
    /// security-scoped access around `body`, mirroring what
    /// `resume(from:)` already does for the initial load. Needed here
    /// because `getImagesAtURL` only loads image data once, eagerly —
    /// its own access window (opened by `resume(from:)`, for a restored
    /// window) closes immediately afterwards, long before a user gets
    /// around to actually copying or sharing an image.
    private func withFolderAccess(_ body: () -> Void) {
        guard let bookmarkData = viewModel.bookmarkData else { return }
        var isStale = false
        guard let folderURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), folderURL.startAccessingSecurityScopedResource() else { return }
        defer { folderURL.stopAccessingSecurityScopedResource() }
        body()
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
