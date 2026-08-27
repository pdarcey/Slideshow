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
                .onDrop(of: ["public.file-url"], isTargeted: $dragOver) { providers -> Bool in
                    providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, error) in
                        if let data = data, let path = NSString(data: data, encoding: 4), let selection = URL(string: path as String) {
                            // loadDataRepresentation's completion handler runs
                            // off the main actor, but the view model isn't —
                            // hop back before touching it.
                            Task { @MainActor in
                                let (folderURL, selectedImage) = viewModel.parseSelectedURL(selection)
                                viewModel.getImagesAtURL(folderURL, selectedImage: selectedImage)
                            }
                        }
                    })
                    return true
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
    }
}

#Preview {
    DefaultView(
        viewModel: ContentView.ViewModel(),
        onStartAtCurrent: {},
        onRestartFromBeginning: {}
    )
}
