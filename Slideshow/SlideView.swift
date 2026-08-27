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
    @FocusState private var focussed: Bool
    @AppStorage("showMetadata") var showMetadata = true
    @State private var scale: CGFloat = 1
    @State private var showHelp = false
    @Environment(\.appearsActive) private var appearsActive
    @State private var window: NSWindow?
    @AppStorage("slideTransition") private var slideTransition: SlideTransition = .crossFade
    @AppStorage("transitionDuration") private var transitionDuration: Double = 0.35

    // Auto Mode
    @AppStorage("autoModeInterval") var interval: Double = 3.0
    @AppStorage("autoMode") var autoMode: Bool = true
    let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    init(slides: [Slide], autoModeInterval: Double = 3.0, currentImage: Int, slideshowIsRunning: Binding<Bool>) {
        self.slides = slides
        self.autoModeInterval = autoModeInterval
        self.currentImage = currentImage
        self._slideshowIsRunning = slideshowIsRunning
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
                    .id(slide.id)
                    .transition(slideTransition == .crossFade ? .opacity : .identity)

                if showMetadata {
                    MetadataTextView(text: "\(currentImage + 1) of \(slides.count): \(slide.imageName.withoutExtension())")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                }

                if showHelp {
                    HelpView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                ScrollZoomView { delta in
                    scale += delta
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .focusable()
        .focused($focussed)
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
                    currentImage -= 1
                }
                return .handled
            }
        }
        .onKeyPress(keys: [.space, .rightArrow, .return], action: { _ in
            withAnimation(.easeInOut(duration: transitionDuration)) {
                autoMode = false
                if (currentImage + 1) < slides.count {
                    // Show next slide
                    currentImage += 1
                } else {
                    // Last slide has been shown, cancel the slideshow
                    endSlideshow()
                }
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
        .onKeyPress(keys: ["="], action: { _ in
            // Return scale to 100%
            withAnimation {
                scale = 1.0
                return .handled
            }
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
                    if (currentImage + 1) < slides.count {
                        // Show next slide
                        currentImage += 1
                    } else {
                        // Last slide has been shown, cancel the slideshow
                        endSlideshow()
                    }
                }
            }
        }
        .onTapGesture(perform: {
            withAnimation(.easeInOut(duration: transitionDuration)) {
                if (currentImage + 1) < slides.count {
                    // Show next slide
                    currentImage += 1
                } else {
                    // Last slide has been shown, cancel the slideshow
                    endSlideshow()
                }
            }
        })
    }

    /// Stops the slideshow and exits full screen. Centralizes the sequence
    /// every "reached the last slide" / "user cancelled" path needs, so it's
    /// defined once instead of repeated at each call site.
    private func endSlideshow() {
        slideshowIsRunning = false
        currentImage = 0
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
        for ext in supportedExtensions {
            if self.lowercased().hasSuffix(ext) {
                return self.replacingOccurrences(of: ext, with: "", options: [.caseInsensitive])
            }
        }
        return self
    }
}
