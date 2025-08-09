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
        Window("Slideshow", id: "contents") {
            ContentView()
        }

        Settings {
            SettingsView()
        }
    }
}
