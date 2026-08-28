//
//  KeyOutline.swift
//  Slideshow
//
//  Created by Paul Darcey on 10/8/2025.
//

import SwiftUI

struct KeyOutline: View {
    var key: String

    var body: some View {
        Text(key)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(5)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.secondary, lineWidth: 1)
            )

    }
}

// MARK: - Previews

#Preview("Dark Mode") {
    KeyOutline(key: "Esc")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    KeyOutline(key: "Esc")
        .padding()
        .preferredColorScheme(.light)
}
