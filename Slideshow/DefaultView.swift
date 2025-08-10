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
    @Binding var startImageIndex: Int

    func selectFileOrFolder() {
        // Display file selection panel
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.bmp, .jpeg, .png, .tiff, .gif, .heic]
        panel.allowsMultipleSelection = false
        panel.prompt = "Start Slideshow"

        if panel.runModal() == .OK, let selection = panel.url {
            let (folderURL, selectedImage) = parseSelectedURL(selection)
            getImagesAtURL(folderURL, selectedImage: selectedImage)
            }
        }

    func parseSelectedURL(_ url: URL) -> (folderURL: URL, selectedImage: URL?) {
        let folderURL: URL
        var selectedImage: URL? = nil
        if url.hasDirectoryPath {
            folderURL = url
        } else {
            folderURL = url.deletingLastPathComponent()
            selectedImage = url
        }
        return (folderURL, selectedImage)
    }

    func getImagesAtURL(_ folderURL: URL, selectedImage: URL? = nil) {
        let fileManager = FileManager.default

        if let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            let sortedImages = files
                .filter { ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            var imageDict: [String:Image] = [:]
            for url in sortedImages {
                guard let nsImage = NSImage(contentsOfFile: url.path) else { break }
                imageDict[url.lastPathComponent] = Image(nsImage: nsImage)
            }
            // Set the variables and start the slideshow
            startImageIndex = 0 // Default
            if let selectedImage, let startIndex = sortedImages.firstIndex(of: selectedImage) {
                startImageIndex = startIndex
            }
            images = imageDict
            heroImage = setHeroImage(for: selectedImage)
            slideshowRunning = true
        }
    }

    func setHeroImage(for selectedImageURL: URL?) -> Image {
        // First, is there a selected file, and can we make it into an image
        if let selectedURL = selectedImageURL, let image = NSImage(contentsOf: selectedURL) {
           return Image(nsImage:image)
        }
        // Second, if not, grab the first image in the `images` dictionary
        if let firstImageURL = Array(images!.keys).sorted().first,
           let image = images?[firstImageURL] {
            return image
        } else {
            // Third, if all else fails, show a default image
            return Image(systemName: "photo.on.rectangle")
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
                        if let data = data, let path = NSString(data: data, encoding: 4), let selection = URL(string: path as String) {
                            let (folderURL, selectedImage) = parseSelectedURL(selection)
                            getImagesAtURL(folderURL, selectedImage: selectedImage)
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
    @Previewable @State var images: [String:Image]? = nil
    @Previewable @State var slideshowRunning: Bool = false
    @Previewable @State var startImageIndex: Int = 0

    DefaultView(images: $images, slideshowRunning: $slideshowRunning, startImageIndex: $startImageIndex)
}
