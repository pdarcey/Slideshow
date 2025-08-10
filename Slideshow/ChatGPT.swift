//
//  ChatGPT.swift
//  Slideshow
//
//  Created by Paul Darcey on 9/8/2025.
//

import SwiftUI
import AppKit

struct ChatGPT: View {
    @State private var imagePaths: [URL] = []
    @State private var currentImageIndex: Int = 0
    @State private var isShowingImage = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                if isShowingImage, !imagePaths.isEmpty {
                    Image(nsImage: NSImage(contentsOf: imagePaths[currentImageIndex]) ?? NSImage())
                        .resizable()
                        .scaledToFit()
                        .opacity(opacity)
                        .animation(.easeInOut(duration: 0.5), value: opacity)
                        .onTapGesture {
                            advanceImage()
                        }
                        .onAppear {
                            opacity = 1.0
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if !imagePaths.isEmpty {
                    thumbnailStrip
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                } else {
                    Button("Choose Image") {
                        chooseStartingImage()
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.black)
        .onKeyPress(keys: [.space, .rightArrow, .return], action: { _ in
            advanceImage()
            return .handled
        })
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                toggleFullScreen()
            }
        }
    }

    // MARK: - Thumbnail Strip View
    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(imagePaths.indices, id: \.self) { index in
                    let thumbnailImage = NSImage(contentsOf: imagePaths[index]) ?? NSImage()
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 60)
                        .clipped()
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(currentImageIndex == index ? Color.blue : Color.clear, lineWidth: 3)
                        )
                        .onTapGesture {
                            switchToImage(at: index)
                        }
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 70)
    }

    // MARK: - Choose folder/image and start slideshow
    private func chooseStartingImage() {
        // Display file selection panel
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.bmp, .jpeg, .png, .tiff, .gif, .heic]
        panel.allowsMultipleSelection = false
        panel.prompt = "Start Slideshow"

        if panel.runModal() == .OK, let selection = panel.url {
            let folderURL: URL
            var selectedImage: URL? = nil
            if selection.hasDirectoryPath {
                folderURL = selection
            } else {
                folderURL = selection.deletingLastPathComponent()
                selectedImage = selection
            }
            let fileManager = FileManager.default

            if let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
                let sortedImages = files
                    .filter { ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"].contains($0.pathExtension.lowercased()) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }

                // Set the variables and start the slideshow
                currentImageIndex = 0 // Default
                if let selectedImage, let startIndex = sortedImages.firstIndex(of: selectedImage) {
                    currentImageIndex = startIndex
                }
                imagePaths = sortedImages
                isShowingImage = true
            }
        }
    }

    private func advanceImage() {
        withAnimation {
            opacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentImageIndex = (currentImageIndex + 1) % imagePaths.count
            withAnimation {
                opacity = 1.0
            }
        }
    }

    private func switchToImage(at index: Int) {
        withAnimation {
            opacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentImageIndex = index
            withAnimation {
                opacity = 1.0
            }
        }
    }

    private func toggleFullScreen() {
        if let window = NSApp.windows.first {
            window.toggleFullScreen(nil)
        }
    }
}

#Preview {
    ChatGPT()
}
