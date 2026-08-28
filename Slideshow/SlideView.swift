//
//  SlideView.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI
import Combine

struct SlideView: View {
    var slides: [Slide]
    var autoModeInterval: Double
    /// Owned by `ContentView`, not local: the app-level Cmd+C/Reveal-in-
    /// Finder/Copy actions and menu commands need to know which slide is
    /// live right now, and a parent view can't reach into a child's local
    /// `@State` from outside — see `ContentView`.
    @Binding var currentImage: Int
    @Binding var slideshowIsRunning: Bool
    /// Called with the last-displayed slide's index whenever the slideshow
    /// ends (Esc, or reaching the last slide), so the caller can make the
    /// picker screen's hero image reflect wherever the user left off.
    var onEnd: (Int) -> Void = { _ in }
    /// Copies the given slide's image to the pasteboard. Handled by
    /// `ContentView`, not here: it needs `viewModel.bookmarkData` to
    /// briefly re-open security-scoped access first, since the original
    /// access window `getImagesAtURL` loaded these images under may
    /// already be long closed by the time a user copies one.
    var onCopyImage: (URL) -> Void = { _ in }
    /// A safe-to-share copy of the given slide's file (see `ContentView`
    /// for why sharing the original URL directly isn't reliable for a
    /// resumed window's folder). Also `ContentView`-owned, same reason as
    /// `onCopyImage`.
    var shareableURL: (URL) -> URL = { $0 }
    /// Shared with `DefaultView`'s hero image (via `ContentView`), so the
    /// current slide morphs from/into the hero image when the slideshow
    /// starts/ends, rather than just cutting or crossfading. See
    /// `ContentView`.
    var namespace: Namespace.ID
    /// True only for the slide actually involved in a hero-image morph:
    /// the first slide shown when the slideshow starts, and (briefly, set
    /// by `endSlideshow()`) whichever slide is showing when it ends. False
    /// for every other, ordinary slide-to-slide navigation — `.id(slide.id)`
    /// gives each slide fresh view identity, so if *every* slide carried
    /// the same matchedGeometryEffect id, SwiftUI would try to morph
    /// between consecutive slides too (replacing the plain crossfade with
    /// odd grow/slide artifacts), not just at the DefaultView boundary.
    @State private var isHeroTransitionSlide = true
    /// Backs the context menu's "Share…" — see `ShareSheetPresenter`.
    @State private var sharePresenter = ShareSheetPresenter()
    @FocusState private var focussed: Bool
    @AppStorage("showMetadata") var showMetadata = true
    /// `scale`/`offset` are also `ContentView`-owned, for the same reason
    /// `currentImage` is: the Reset Zoom menu command needs to reach them
    /// from outside this view.
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @State private var dragStartOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5
    private let zoomStep: CGFloat = 0.25
    /// Also `ContentView`-owned, so the Toggle Help menu command can reach
    /// it — same reasoning as `currentImage`/`scale`/`offset`.
    @Binding var showHelp: Bool
    @Environment(\.appearsActive) private var appearsActive
    @State private var window: NSWindow?
    @AppStorage("slideTransition") private var slideTransition: SlideTransition = .crossFade
    @AppStorage("transitionDuration") private var transitionDuration: Double = 0.35

    // Auto Mode
    @AppStorage("autoModeInterval") var interval: Double = 3.0
    @AppStorage("autoMode") var autoMode: Bool = true
    let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    init(
        slides: [Slide],
        autoModeInterval: Double = 3.0,
        currentImage: Binding<Int>,
        slideshowIsRunning: Binding<Bool>,
        showHelp: Binding<Bool>,
        scale: Binding<CGFloat>,
        offset: Binding<CGSize>,
        namespace: Namespace.ID,
        onCopyImage: @escaping (URL) -> Void = { _ in },
        shareableURL: @escaping (URL) -> URL = { $0 },
        onEnd: @escaping (Int) -> Void = { _ in }
    ) {
        self.slides = slides
        self.autoModeInterval = autoModeInterval
        self._currentImage = currentImage
        self._slideshowIsRunning = slideshowIsRunning
        self._showHelp = showHelp
        self._scale = scale
        self._offset = offset
        self.namespace = namespace
        self.onCopyImage = onCopyImage
        self.shareableURL = shareableURL
        self.onEnd = onEnd
        self.timer = Timer.publish(every: autoModeInterval, on: .main, in: .common).autoconnect()
    }

    var body: some View {
        ZStack {
            if slides.indices.contains(currentImage) {
                let slide = slides[currentImage]
                Color.black.edgesIgnoringSafeArea(.all)
                // Only the image content itself gets a fresh identity per
                // slide (needed for .transition to actually animate an
                // insert/remove between photos). Focus and all the key
                // handling below live on the outer ZStack instead, which
                // never changes identity — otherwise every keyboard
                // shortcut breaks on every slide change.
                slide.image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .id(slide.id)
                    .transition(slideTransition == .crossFade ? .opacity : .identity)
                    .matchedGeometryEffect(id: isHeroTransitionSlide ? "hero" : "slide-\(slide.id)", in: namespace)
                    .contextMenu {
                        Button("Copy Image", systemImage: "doc.on.doc") {
                            onCopyImage(slide.url)
                        }
                        Button("Reveal in Finder", systemImage: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([slide.url])
                        }
                        Button("Share…", systemImage: "square.and.arrow.up") {
                            presentShareSheet(for: shareableURL(slide.url))
                        }
                    }

                if showMetadata {
                    MetadataTextView(text: "\(currentImage + 1) of \(slides.count): \(slide.imageName.withoutExtension())")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                }

                if showHelp {
                    HelpView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                ScrollZoomView(
                    onScroll: { delta in
                        setScale(scale + delta)
                    },
                    onMagnify: { delta in
                        setScale(scale + delta)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .focusable()
        .focused($focussed)
        .onGeometryChange(for: CGSize.self, of: \.size) { newSize in
            containerSize = newSize
        }
        .onAppear {
            focussed = true
            captureWindowIfNeeded()
        }
        .onChange(of: appearsActive) { _, _ in
            captureWindowIfNeeded()
        }
        .onKeyPress(.escape) {
            // User has hit Esc, cancel the slideshow
            withAnimation {
                endSlideshow()
                return .handled
            }
        }
        .onKeyPress(.leftArrow) {
            withAnimation(.easeInOut(duration: transitionDuration)) {
                autoMode = false
                if currentImage > 0 {
                    // Show previous slide
                    isHeroTransitionSlide = false
                    currentImage -= 1
                }
                return .handled
            }
        }
        .onKeyPress(keys: [.space, .rightArrow, .return], action: { _ in
            withAnimation(.easeInOut(duration: transitionDuration)) {
                autoMode = false
                advanceSlide()
                return .handled
            }
        })
        .onKeyPress(keys: ["=", "+"], action: { press in
            // Cmd+= (or Cmd++, on keyboards/layouts that send "+" directly):
            // zoom in a step. Bare "=" (reset to 100%) is a menu-bar
            // command now (see SlideshowApp) rather than handled here —
            // menu shortcuts intercept before a view's onKeyPress ever
            // sees them, so a duplicate case here would just be dead code.
            guard press.modifiers.contains(.command) else { return .ignored }
            withAnimation {
                setScale(scale + zoomStep)
            }
            return .handled
        })
        .onKeyPress(keys: ["-"], action: { press in
            // Cmd-minus: zoom out a step. Bare "-" isn't bound to anything.
            guard press.modifiers.contains(.command) else { return .ignored }
            withAnimation {
                setScale(scale - zoomStep)
            }
            return .handled
        })
        .onReceive(timer) { _ in
            // Automode progress
            if autoMode {
                guard !slides.isEmpty else { return }
                withAnimation(.easeInOut(duration: transitionDuration)) {
                    advanceSlide()
                }
            }
        }
        .onTapGesture(perform: {
            withAnimation(.easeInOut(duration: transitionDuration)) {
                advanceSlide()
            }
        })
        .simultaneousGesture(panGesture)
    }

    /// Drags the zoomed image around within the window. A no-op at 100%
    /// (`scale == 1`) so it never competes with tap-to-advance when the
    /// image isn't zoomed — there's nothing to pan at that point anyway.
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = clampedOffset(CGSize(
                    width: dragStartOffset.width + value.translation.width,
                    height: dragStartOffset.height + value.translation.height
                ))
            }
            .onEnded { _ in
                dragStartOffset = offset
            }
    }

    /// Clamps `scale` to a sane range and re-clamps `offset` to match, so
    /// every zoom input — scroll wheel, pinch, keyboard — shares one code
    /// path and panning never ends up out of bounds after a zoom change.
    private func setScale(_ newScale: CGFloat) {
        scale = min(max(newScale, minScale), maxScale)
        offset = clampedOffset(offset)
    }

    /// Approximates how far the image can be panned at the current scale:
    /// the container's own size scaled by (scale - 1), halved per axis.
    /// Not pixel-perfect against the actual aspect-fit image bounds when a
    /// photo doesn't fill the container in both dimensions, but close
    /// enough to keep it from being dragged fully off-screen.
    private func clampedOffset(_ proposed: CGSize) -> CGSize {
        let maxX = containerSize.width * (scale - minScale) / 2
        let maxY = containerSize.height * (scale - minScale) / 2
        guard maxX > 0 || maxY > 0 else { return .zero }
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    /// Shows the next slide, or ends the slideshow if this was the last
    /// one. Shared by the right-arrow/space/return key handler, the
    /// auto-mode timer, and tap-to-advance — all three do exactly this.
    private func advanceSlide() {
        if (currentImage + 1) < slides.count {
            isHeroTransitionSlide = false
            currentImage += 1
        } else {
            endSlideshow()
        }
    }

    /// Stops the slideshow and exits full screen. Centralizes the sequence
    /// every "reached the last slide" / "user cancelled" path needs, so it's
    /// defined once instead of repeated at each call site. Doesn't reset
    /// `currentImage`: this SlideView instance is discarded, not reused —
    /// `ContentView` constructs a brand new one, with fresh @State, the
    /// next time a slideshow starts.
    private func endSlideshow() {
        // The slide on screen right now is what should morph back into the
        // hero image, whatever it is — re-mark it as the transition slide
        // even if the user long since navigated away from the entry slide.
        isHeroTransitionSlide = true
        onEnd(currentImage)
        slideshowIsRunning = false
        exitFullScreen()
    }

    /// Shows the Share Sheet anchored at the current mouse position rather
    /// than `ShareLink`'s automatic positioning, which places the popover
    /// off-screen (and, since it's still modally presented, stuck there)
    /// when this window is full-screen — see `ShareSheetPresenter`.
    private func presentShareSheet(for url: URL) {
        guard let window, let contentView = window.contentView else { return }
        let locationInWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let anchor = NSRect(origin: locationInWindow, size: .zero)
        sharePresenter.present(url, relativeTo: anchor, of: contentView, preferredEdge: .minY)
    }

    /// Captures this view's own hosting window the first time it's known to
    /// be active, then enters full screen. Using `appearsActive` rather than
    /// `NSApplication.shared.windows.last`/`.keyWindow` means this reliably
    /// targets *this* SlideView's window even when other Slideshow windows
    /// are open at the same time.
    private func captureWindowIfNeeded() {
        guard appearsActive, window == nil else { return }
        window = NSApplication.shared.keyWindow
        if let window, !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }

    private func exitFullScreen() {
        // Toggle off full-screen mode, if necessary
        guard let window, window.styleMask.contains(.fullScreen) else { return }
        Task { @MainActor in
            window.toggleFullScreen(nil)
        }
    }
}

extension String {
    func withoutExtension() -> String {
        let supportedExtensions = [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".heic", ".tiff"]
        for ext in supportedExtensions where self.lowercased().hasSuffix(ext) {
            return self.replacingOccurrences(of: ext, with: "", options: [.caseInsensitive])
        }
        return self
    }
}
