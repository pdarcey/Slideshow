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

struct KeyDescription: View {
    var keys: [String]
    var description: String

    init(keys: String..., description: String) {
        self.keys = keys
        self.description = description
    }
    var body: some View {
        LabeledContent(content: {
            OutlineText(text: description)
        }, label: {
            HStack {
                ForEach(keys, id: \.self) { key in
                    KeyOutline(key: key)
                        .padding(.trailing, 3)
                }
            }
        })
    }
}

struct KeyOutline: View {
    var key: String

    var body: some View {
        Text(key)
            .font(.subheadline)
            .foregroundStyle(Color.white)
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

#Preview {
    HelpView()
}
