//
//  SlideView.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

struct SlideView: View {
    var images: [Image]
    @State var currentImage: Int = 0
    @Binding var slideshowIsRunning: Bool
    @FocusState private var focussed: Bool

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            images[currentImage]
                .resizable()
                .aspectRatio(contentMode: .fit)
                .focusable()
                .focused($focussed)
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

            Text("\(currentImage + 1) of \(images.count)")
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, maxHeight: .infinity, alignment: .topLeading)
                .padding()

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

#Preview {
    SlideView(images: previewImages, slideshowIsRunning: .constant(true))
}
