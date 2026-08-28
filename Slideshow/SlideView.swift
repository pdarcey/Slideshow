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
    @State var currentImage: Int = 0
    @Binding var slideshowIsRunning: Bool
    /// Called with the last-displayed slide's index whenever the slideshow
    /// ends (Esc, or reaching the last slide), so the caller can make the
    /// picker screen's hero image reflect wherever the user left off.
    var onEnd: (Int) -> Void = { _ in }
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
    @FocusState private var focussed: Bool
    @AppStorage("showMetadata") var showMetadata = true
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5
    private let zoomStep: CGFloat = 0.25
    @State private var showHelp = false
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
        currentImage: Int,
        slideshowIsRunning: Binding<Bool>,
        namespace: Namespace.ID,
        onEnd: @escaping (Int) -> Void = { _ in }
    ) {
        self.slides = slides
        self.autoModeInterval = autoModeInterval
        self.currentImage = currentImage
        self._slideshowIsRunning = slideshowIsRunning
        self.namespace = namespace
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
        .onKeyPress(keys: ["m", "M"], action: { _ in
            // Show/Hide metadata (i.e. "1 of 100: <filename>")
            withAnimation {
                showMetadata.toggle()
                return .handled
            }
        })
        .onKeyPress(keys: ["a", "A"], action: { _ in
            // Toggle autoMode
            withAnimation {
                autoMode.toggle()
                return .handled
            }
        })
        .onKeyPress(keys: ["=", "+"], action: { press in
            // Bare "=": reset scale/offset to 100%. Cmd+= (or Cmd++, on
            // keyboards/layouts that send "+" directly): zoom in a step.
            guard press.modifiers.contains(.command) || press.key == "=" else { return .ignored }
            withAnimation {
                if press.modifiers.contains(.command) {
                    setScale(scale + zoomStep)
                } else {
                    resetZoom()
                }
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
        .onKeyPress(keys: ["?"], action: { _ in
            // Toggle Help display
            withAnimation {
                showHelp.toggle()
                return .handled
            }
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

    private func resetZoom() {
        scale = minScale
        offset = .zero
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
