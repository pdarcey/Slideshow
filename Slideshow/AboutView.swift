//
//  AboutView.swift
//  Slideshow
//
//  Created by Paul Darcey on 9/8/2025.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        HStack {
            Image("AboutIcon")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(radius: 3)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 15)
//                        .stroke(Color.white, lineWidth: 3)
//                )
            VStack {
                Text("Slideshow")
                    .font(.largeTitle)
                    .bold()

                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("© 2025 Xerodonia Pty Ltd, All rights reserved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .frame(height: 104)
        .backgroundStyle(.quaternary)
        .padding()
    }
}

#Preview {
    AboutView()
        .border(Color.blue)
        .padding()
}
