//
//  HelpView.swift
//  Slideshow
//
//  Created by Paul Darcey on 10/8/2025.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack {
            Text("Help")
                .font(.headline)
                .padding(.bottom, 10)

            Form {
                KeyDescription(keys: "Esc", description: "End slideshow")
                KeyDescription(keys: "Right Arrow", "Space", "Return", description: "Show next slide")
                KeyDescription(keys: "Left Arrow", description: "Show previous slide")
                KeyDescription(keys: "M", description: "Toggle metadata")
                KeyDescription(keys: "A", description: "Toggle AutoMode")
                KeyDescription(keys: "=", description: "Set scale to 100%")
                KeyDescription(keys: "?", description: "Toggle Help")
                KeyDescription(keys: "Scroll Up/Down", description: "Zoom In/Out")
            }
        }
        .padding()
        .opacity(0.9)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 8)
        )

    }
}

// MARK: - Previews

#Preview("Dark Mode") {
    HelpView()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    HelpView()
        .preferredColorScheme(.light)
}
