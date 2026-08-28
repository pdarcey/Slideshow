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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @FocusedValue(\.slideshowWindow) private var slideshowWindow

    init() {
        // Multiple Slideshow windows are fine; the native window-tabbing UI
        // (merging them into tabs) doesn't suit this app.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup("Slideshow", id: "contents") {
            ContentView()
        }
        .windowIdealPlacement { _, _ in
            WindowPlacement(size: CGSize(width: 1500, height: 1500))
        }
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button {
                    openWindow(id: "about")
                } label: {
                    Text("About Slideshow")
                }
            }

                CommandGroup(replacing: .help) {
                    Button("Slideshow Help") {
                        openWindow(id: "help")
                    }
                    .keyboardShortcut("?", modifiers: [.command, .shift])
                }

            CommandGroup(after: .newItem) {
                Button("Open…") {
                    slideshowWindow?.viewModel.selectFileOrFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("Slideshow") {
                Button("Continue") {
                    slideshowWindow?.startAtCurrent()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(slideshowWindow?.canStartSlideshow != true)

                Button("Re-start from Beginning") {
                    slideshowWindow?.restartFromBeginning()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(slideshowWindow?.canStartSlideshow != true)
            }
        }

        Window("Slideshow Help", id: "help") {
            HelpView()
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .containerBackground(.thickMaterial, for: .window)
                .windowMinimizeBehavior(.disabled)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

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
