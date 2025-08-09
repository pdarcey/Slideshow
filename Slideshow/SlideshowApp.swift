//
//  SlideshowApp.swift
//  Slideshow
//
//  Created by Paul Darcey on 24/8/2023.
//

import SwiftUI

@main
struct SlideshowApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Slideshow", id: "contents") {
            ContentView()
        }
        .windowIdealPlacement { content, context in
//            var size = content.sizeThatFits(.unspecified)
            let displayBounds = context.defaultDisplay.visibleRect
            // modify size based on display bounds
            return WindowPlacement(size: displayBounds.size)
        }
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button {
                    openWindow(id: "about")
                } label: {
                    Text("About Slideshow")
                }
            }
        }

        Window("About Slideshow", id: "about") {
            AboutView()
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .containerBackground(.thickMaterial, for: .window)
                .windowMinimizeBehavior(.disabled)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

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
