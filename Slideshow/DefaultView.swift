//
//  DefaultView.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

struct DefaultView: View {
    var viewModel: ContentView.ViewModel
    var onStartAtCurrent: () -> Void
    var onRestartFromBeginning: () -> Void

    @State private var dragOver = false
    @SceneStorage("selectedFolder") private var selectedFolder = URL.picturesDirectory

    var body: some View {
        let check = viewModel.images.count
        VStack {
            Text(check > 0 ? "Selected folder: \(selectedFolder.lastPathComponent)  (\(check.formatted()) images)" : "")

            if viewModel.images.isEmpty {
                ContentUnavailableView("Choose a folder of images to display", systemImage: "photo.on.rectangle")
                Spacer()
            } else {
                viewModel.selectedImage
                    .resizable()
                    .scaledToFit()
                    .padding(.bottom)
            }

            HStack {
                Button("Select folder") {
                    viewModel.selectFileOrFolder()
                }

                if !viewModel.images.isEmpty {
                    Button("Start") {
                        onStartAtCurrent()
                    }

                    Button("Re-start from Beginning") {
                        onRestartFromBeginning()
                    }
                }
            }
        }
        .padding()
        // The whole picker screen is the drop target now, not just the
        // "Select folder" button — and dragOver (already tracked, but
        // previously never actually shown) now drives a visible highlight.
        .dropDestination(for: URL.self) { urls, _ in
            guard let selection = urls.first else { return false }
            Task { @MainActor in
                let (folderURL, selectedImage) = viewModel.parseSelectedURL(selection)
                viewModel.getImagesAtURL(folderURL, selectedImage: selectedImage)
            }
            return true
        } isTargeted: { targeted in
            dragOver = targeted
        }
        .overlay {
            if dragOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(4)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: dragOver)
    }
}

#Preview {
    DefaultView(
        viewModel: ContentView.ViewModel(),
        onStartAtCurrent: {},
        onRestartFromBeginning: {}
    )
}
