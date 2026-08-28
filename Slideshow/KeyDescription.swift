//
//  KeyDescription.swift
//  Slideshow
//
//  Created by Paul Darcey on 10/8/2025.
//

import SwiftUI

struct KeyDescription: View {
    var keys: [String]
    var description: String

    init(keys: String..., description: String) {
        self.keys = keys
        self.description = description
    }
    var body: some View {
        LabeledContent(content: {
            Text(description)
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

// MARK: - Previews

#Preview("Dark Mode") {
    Form {
        KeyDescription(keys: "Esc", description: "End slideshow")
    }
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    Form {
        KeyDescription(keys: "Esc", description: "End slideshow")
    }
    .preferredColorScheme(.light)
}
