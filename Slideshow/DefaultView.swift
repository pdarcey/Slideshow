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

    var body: some View {
        VStack {
            if viewModel.images.isEmpty {
                switch viewModel.emptyReason {
                case .accessDenied:
                    ContentUnavailableView(
                        "Can't Access That Folder",
                        systemImage: "lock.fill",
                        // swiftlint:disable:next line_length
                        description: Text("macOS only grants Slideshow access to a single file on its own, not the folder it's in. Click **Select Folder or Image…** below, or drag onto this window, and choose the folder instead.")
                    )
                case .noSupportedImages:
                    ContentUnavailableView(
                        "No Images Found",
                        image: "photo.stack.slash",
                        // swiftlint:disable:next line_length
                        description: Text("That folder doesn't contain any supported images. Click **Select Folder or Image…** below to try a different one.")
                    )
                case .previousFolderUnavailable:
                    ContentUnavailableView(
                        "Folder No Longer Available",
                        systemImage: "folder.badge.questionmark",
                        // swiftlint:disable:next line_length
                        description: Text("The folder this window had open isn't available any more. It may have been moved, renamed, or deleted. Click **Select Folder or Image…** below to choose another.")
                    )
                case .notYetAttempted:
                    // swiftlint:disable:next line_length
                    ContentUnavailableView("Choose a folder of images, or a single image, to display", systemImage: "photo.on.rectangle")
                }
                Spacer()
            } else {
                viewModel.selectedImage
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.separator, lineWidth: 1)
                    }
                    .shadow(radius: 8)
                    .padding(.bottom)
            }

            HStack {
                // buttonStyle's argument is `some ButtonStyle`, so the two
                // branches can't share one Button behind a ternary — each
                // concrete style (.borderedProminent vs .bordered) is its
                // own opaque type. Branching the whole button is the
                // standard way around that.
                if viewModel.images.isEmpty {
                    Button("Select Folder or Image…", systemImage: "folder") {
                        viewModel.selectFileOrFolder()
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Select Folder or Image…")
                } else {
                    Button("Select Folder or Image…", systemImage: "folder") {
                        viewModel.selectFileOrFolder()
                    }
                    .buttonStyle(.bordered)
                    .help("Select Folder or Image…")
                }

                if !viewModel.images.isEmpty {
                    Button("Start", systemImage: "play.fill") {
                        onStartAtCurrent()
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Start")

                    Button("Re-start from Beginning", systemImage: "arrow.counterclockwise") {
                        onRestartFromBeginning()
                    }
                    .buttonStyle(.bordered)
                    .help("Re-start from Beginning")
                }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
        .padding()
        // The whole picker screen is the drop target now, not just the
        // "Select Folder or Image…" button — and dragOver (already
        // tracked, but previously never actually shown) now drives a
        // visible highlight.
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
