//
//  SlideView.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI
import Combine

struct SlideView: View {
    var images: [Image]
    var autoModeInterval: Double
    @State var currentImage: Int = 0
    @Binding var slideshowIsRunning: Bool
    @FocusState private var focussed: Bool
    @AppStorage("showMetadata") var showMetadata = true

    // Auto Mode
    @AppStorage("autoModeInterval") var interval: Double = 3.0
    @AppStorage("autoMode") var autoMode: Bool = true
    let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    init(images: [Image], autoModeInterval: Double = 3.0, currentImage: Int, slideshowIsRunning: Binding<Bool>) {
        self.images = images
        self.autoModeInterval = autoModeInterval
        self.currentImage = currentImage
        self._slideshowIsRunning = slideshowIsRunning
        self.timer = Timer.publish(every: autoModeInterval, on: .main, in: .common).autoconnect()
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            images[currentImage]
                .resizable()
                .aspectRatio(contentMode: .fit)
                .focusable()
                .focused($focussed)
                .transition(.opacity)
                .onAppear {
                    focussed = true
                }
                .onExitCommand(perform: {
                    withAnimation {
                        // User has hit Esc, cancel the slideshow
                        slideshowIsRunning = false
                        currentImage = 0
                    }
                })
                .onKeyPress(.escape) {
                    withAnimation {
                        // User has hit Esc, cancel the slideshow
                        slideshowIsRunning = false
                        currentImage = 0
                        return .handled
                    }
                }
                .onKeyPress(.leftArrow) {
                    withAnimation {
                        if currentImage > 0 {
                            // Show previous slide
                            currentImage -= 1
                        }
                        return .handled
                    }
                }
                .onKeyPress(keys: [.space, .rightArrow, .return], action: { _ in
                    withAnimation {
                        if (currentImage + 1) < images.count {
                            // Show next slide
                            currentImage += 1
                        } else {
                            // Last slide has been shown, cancel the slideshow
                            slideshowIsRunning = false
                            currentImage = 0
                        }
                        return .handled
                    }
                })
                .onKeyPress(keys: ["h", "H"], action: { _ in
                    // Show/Hide metadata (i.e. "1 of 100: <filename>")
                    withAnimation {
                        showMetadata.toggle()
                        return .handled
                    }
                }
                )
                .onKeyPress(keys: ["a", "A"], action: { _ in
                    // Toggle autoMode
                    withAnimation {
                        autoMode.toggle()
                        return .handled
                    }
                }
                )
                .onReceive(timer) { _ in
                    // Automode progress
                    if autoMode {
                        guard !images.isEmpty else { return }
                        withAnimation {
                            if (currentImage + 1) < images.count {
                                // Show next slide
                                currentImage += 1
                            } else {
                                // Last slide has been shown, cancel the slideshow
                                slideshowIsRunning = false
                                currentImage = 0
                            }
                        }
                    }
                }

            if showMetadata {
                Text("\(currentImage + 1) of \(images.count): <filename>")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
            }
        }
        .onTapGesture(perform: {
            withAnimation {
                if (currentImage + 1) < images.count {
                    // Show next slide
                    currentImage += 1
                } else {
                    // Last slide has been shown, cancel the slideshow
                    slideshowIsRunning = false
                    currentImage = 0
                }
            }
        })
    }
}

//#Preview {
//    SlideView(images: previewImages, slideshowIsRunning: .constant(true))
//}
