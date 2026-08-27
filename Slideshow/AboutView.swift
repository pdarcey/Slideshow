//
//  AboutView.swift
//  Slideshow
//
//  Created by Paul Darcey on 9/8/2025.
//

import SwiftUI

struct AboutView: View {
    private var appVersionAndBuild: String {
        let version = Bundle.main
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        let build = Bundle.main
            .infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        return "Version \(version) (\(build))"
    }

    private var copyright: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return "© \(year) Xerodonia Pty Ltd"
    }

    private var developerWebsite: URL {
        URL(string: "https://xerodonia.com/")!
    }
    var body: some View {
        HStack {
            Image("AboutIcon")
                .resizable().scaledToFit()
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
                Spacer()
                VStack(spacing: 2) {
                    Text(appVersionAndBuild)
                    Text(copyright)
                    Link("xerodonia.com", destination: developerWebsite)
                }
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
