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
    // Shared with SlideView via the same @AppStorage keys, so a menu
    // toggle here and the in-slideshow state stay in sync automatically —
    // no FocusedValue plumbing needed for these two specifically.
    @AppStorage("showMetadata") private var showMetadata = true
    @AppStorage("autoMode") private var autoMode = true

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

            // Not slideshow-specific — toggling full screen is valid for
            // the picker window too — so it lives outside "Slideshow"
            // below. Cmd+F is unusual (the system standard is
            // Cmd+Ctrl+F), but confirmed intentional.
            CommandGroup(after: .toolbar) {
                Button("Toggle Full Screen") {
                    NSApplication.shared.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: .command)
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

                Divider()

                // Deliberately not CommandGroup(replacing: .pasteboard):
                // that placement's Cmd+C is validated against the classic
                // copy(_:) responder-chain selector, which nothing in this
                // app implements — it stayed stubbornly disabled even
                // with .disabled(false) set explicitly. A plain custom
                // command here, same as the four below it, isn't tied to
                // that selector and works normally.
                Button("Copy Image") {
                    slideshowWindow?.copyImage()
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(slideshowWindow?.isSlideshowRunning != true)

                Divider()

                // Bare (unmodified) shortcuts, matching SlideView's
                // existing in-slideshow key handling exactly — a menu
                // shortcut is matched before a focused view's onKeyPress,
                // so these are now the one place M/A/?/reset-zoom are
                // actually handled, not a duplicate of it.
                Button("Toggle Metadata") {
                    showMetadata.toggle()
                }
                .keyboardShortcut("m", modifiers: [])
                .disabled(slideshowWindow?.isSlideshowRunning != true)

                Button("Toggle Auto Mode") {
                    autoMode.toggle()
                }
                .keyboardShortcut("a", modifiers: [])
                .disabled(slideshowWindow?.isSlideshowRunning != true)

                Button("Toggle Help Overlay") {
                    slideshowWindow?.toggleHelp()
                }
                .keyboardShortcut("?", modifiers: [])
                .disabled(slideshowWindow?.isSlideshowRunning != true)

                Button("Reset Zoom") {
                    slideshowWindow?.resetZoom()
                }
                .keyboardShortcut("=", modifiers: [])
                .disabled(slideshowWindow?.isSlideshowRunning != true)
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
