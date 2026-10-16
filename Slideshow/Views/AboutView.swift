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
            // The app's real icon, exactly as the Dock shows it: the Liquid
            // Glass AppIcon.icon on macOS 26, or Xcode's generated fallback on
            // earlier releases. It already carries the system shape, margin
            // and shadow, so no clipping or shadow here — and no separate
            // copy of the artwork to keep in sync.
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().scaledToFit()
                // Purely decorative — "Slideshow" right next to it already
                // conveys the app's identity to VoiceOver.
                .accessibilityHidden(true)
            VStack {
                Text("Slideshow")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                VStack(spacing: 2) {
                    Text(appVersionAndBuild)
                    Text(copyright)
                    Link("xerodonia.com", destination: developerWebsite)
                        .foregroundStyle(Color(nsColor: .linkColor))
                        .focusEffectDisabled()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)
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
