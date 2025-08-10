//
//  MetadataTextView.swift
//  Slideshow
//
//  Created by Paul Darcey on 9/8/2025.
//

import SwiftUI

struct MetadataTextView: View {
    let text: String
    let outlineWidth: CGFloat = 1.0 // Adjust for desired outline thickness

    var body: some View {
        ZStack {
            Group {
                // Black text offset in multiple directions to create the outline
                Text(text).offset(x: -outlineWidth, y: -outlineWidth)
                Text(text).offset(x: -outlineWidth, y: outlineWidth)
                Text(text).offset(x: outlineWidth, y: -outlineWidth)
                Text(text).offset(x: outlineWidth, y: outlineWidth)
                Text(text).offset(x: -outlineWidth, y: 0)
                Text(text).offset(x: outlineWidth, y: 0)
                Text(text).offset(x: 0, y: -outlineWidth)
                Text(text).offset(x: 0, y: outlineWidth)
            }
            .foregroundStyle(.black)

            // White text on top
            Text(text).foregroundStyle(.white)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(
            .thinMaterial,
            in: Capsule()
        )
    }
}

#Preview {
    ZStack {
        Color.blue
            .frame(width: 300, height: 200)
        MetadataTextView(text: "Test String")
            .padding(10)
    }
}
