//
//  DefaultView.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

struct DefaultView: View {
    @Binding var images: [String:Image]?
    @Binding var slideshowRunning: Bool
    @State private var dragOver = false
    @State private var heroImage: Image?
    @SceneStorage("selectedFolder") private var selectedFolder = URL.picturesDirectory

    func selectFileOrFolder() {
        var fileSystemReader = FileSystemReader()
        if let fileOrFolderURL = fileSystemReader.selectedFileorFolder() {
            selectedFolder = fileOrFolderURL
            images = fileSystemReader.getImages(at: fileOrFolderURL)
            if let heroImageURL = fileSystemReader.selectedImageURL(),
               let image = NSImage(contentsOf: heroImageURL) {
                heroImage = Image(nsImage:image)
            }
        }
    }

    var body: some View {
        let check = images?.count ?? 0
        VStack {
            Text(check > 0 ? "Selected folder: \(selectedFolder.lastPathComponent)  (\(check.formatted()) images)" : "")

            if let heroImage {
                heroImage
                    .resizable()
                    .scaledToFit()
                    .padding(.bottom)
            } else {
               ContentUnavailableView("Choose a folder of images to display", systemImage: "photo.on.rectangle")
                Spacer()
            }

            HStack {
                Button("Select folder") {
                    selectFileOrFolder()
                }
                .onDrop(of: ["public.file-url"], isTargeted: $dragOver) { providers -> Bool in
                    providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, error) in
                        if let data = data, let path = NSString(data: data, encoding: 4), let fileOrFolderURL = URL(string: path as String) {
                            let fileSystemReader = FileSystemReader()
                            selectedFolder = fileOrFolderURL
                            images = fileSystemReader.getImages(at: fileOrFolderURL)
                            if let heroImageURL = fileSystemReader.selectedImageURL(),
                               let image = NSImage(contentsOf: heroImageURL) {
                                heroImage = Image(nsImage:image)
                            }
                        }
                    })
                    return true
                }

                Button("Start") {
                    withAnimation {
                        slideshowRunning = true
                    }
                }
                .disabled(images?.count == 0)
            }
        }
        .padding()
    }
}

#Preview {
    DefaultView(images: .constant(nil), slideshowRunning: .constant(false))
}
