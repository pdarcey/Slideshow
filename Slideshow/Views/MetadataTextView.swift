//
//  MetadataTextView.swift
//  Slideshow
//
//  Created by Paul Darcey on 9/8/2025.
//

import SwiftUI

struct MetadataTextView: View {
    let text: String

    var body: some View {
        OutlineText(text: text)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(
                .thinMaterial,
                in: Capsule()
            )
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        Color.blue
            .frame(width: 300, height: 200)
        MetadataTextView(text: "Test String")
            .padding(10)
    }
}
