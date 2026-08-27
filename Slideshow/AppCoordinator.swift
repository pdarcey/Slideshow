//
//  AppCoordinator.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import SwiftUI

/// Holds a weak reference so a registry doesn't keep a closed window's
/// view model alive.
private struct Weak<T: AnyObject> {
    weak var value: T?
}

/// Bridges Finder/Dock file-open events (delivered to `AppDelegate`, which
/// isn't a View and so has no `@Environment`) into SwiftUI's window-opening
/// machinery, and decides whether to reuse an already-open empty picker
/// window or open a new one.
///
/// `.shared` is a pragmatic exception to generally avoiding singletons —
/// there's exactly one `NSApplicationDelegate` for the app's lifetime, and
/// it needs a stable way to reach whichever `ContentView`s currently exist.
@Observable
@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private init() {}

    private var viewModels: [Weak<ContentView.ViewModel>] = []
    var openWindowAction: OpenWindowAction?

    /// Set when a new window needs to be created and told what to load
    /// once it appears. A freshly-opened `ContentView` consumes this once.
    var pendingURL: URL?

    func register(_ viewModel: ContentView.ViewModel) {
        viewModels.append(Weak(value: viewModel))
    }

    func unregister(_ viewModel: ContentView.ViewModel) {
        viewModels.removeAll { $0.value === viewModel || $0.value == nil }
    }

    /// Routes a Finder/Dock-opened file into an existing empty picker
    /// window if one exists, or opens a new window for it otherwise.
    func open(_ url: URL) {
        viewModels.removeAll { $0.value == nil }

        if let existing = viewModels.first(where: { $0.value?.images.isEmpty == true })?.value {
            let (folderURL, selectedImage) = existing.parseSelectedURL(url)
            existing.getImagesAtURL(folderURL, selectedImage: selectedImage)
            // Bringing the whole app forward rather than raising the one
            // specific window — tracking a per-view-model NSWindow reference
            // just for this would add real complexity for a minor polish gain.
            NSApp.activate(ignoringOtherApps: true)
        } else {
            pendingURL = url
            openWindowAction?(id: "contents")
        }
    }
}
