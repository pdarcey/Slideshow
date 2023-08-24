//
//  DefaultView.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

struct DefaultView: View {
    @Binding var images: [Image]?
    @Binding var slideshowRunning: Bool

    var folderText: String {
        if let images {
            if images.count > 0 {
                return "Selected \(images.count.formatted()) images"
            }
        }
        return "Select folder"
    }

    var body: some View {
        VStack {
            Button(folderText) {
                let fileSystemReader = FileSystemReader()
                images = fileSystemReader.selectFolder()
            }
            .padding(.bottom)
            Button("Start") {
                slideshowRunning = true
            }
            .disabled(images?.count == 0)
        }

    }
}

#Preview {
    DefaultView(images: .constant(nil), slideshowRunning: .constant(false))
}
