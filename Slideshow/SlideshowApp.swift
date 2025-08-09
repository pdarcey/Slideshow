//
//  SlideshowApp.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

@main
struct SlideshowApp: App {
    var body: some Scene {
        Window("About Slideshow", id: "about") {
            AboutView()
        }

        WindowGroup("Slideshow", id: "contents") {
            ContentView()
        }
        .windowIdealPlacement { content, context in
            var size = content.sizeThatFits(.unspecified)
            let displayBounds = context.defaultDisplay.visibleRect
            // modify size based on display bounds
            return WindowPlacement(size: displayBounds.size)
        }

        Settings {
            SettingsView()
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .containerBackground(.thickMaterial, for: .window)
                .windowMinimizeBehavior(.disabled)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
    }
}
