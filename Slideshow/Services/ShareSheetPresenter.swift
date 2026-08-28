//
//  ShareSheetPresenter.swift
//  Slideshow
//
//  Created by Paul Darcey on 28/8/2026.
//

import AppKit

/// Shows the system Share Sheet (`NSSharingServicePicker`) anchored to an
/// arbitrary rect — used to anchor it at the mouse pointer rather than
/// SwiftUI's `ShareLink`, whose automatic positioning (relative to the
/// source view's frame) places the popover off-screen when the window is
/// full-screen, making it both invisible and — since it's still modally
/// presented — stuck there, locking the UI until dismissed blind.
///
/// A plain SwiftUI closure can't be the picker's delegate (it needs an
/// `NSObject` conforming to `NSSharingServicePickerDelegate`), and the
/// picker itself must be retained for the duration it's on screen or it
/// can be deallocated mid-presentation — this class exists to hold that
/// reference and release it once the picker's finished.
@MainActor
final class ShareSheetPresenter: NSObject, NSSharingServicePickerDelegate {
    private var picker: NSSharingServicePicker?

    func present(_ url: URL, relativeTo rect: NSRect, of view: NSView, preferredEdge: NSRectEdge) {
        let picker = NSSharingServicePicker(items: [url])
        picker.delegate = self
        self.picker = picker
        picker.show(relativeTo: rect, of: view, preferredEdge: preferredEdge)
    }

    nonisolated func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        didChoose service: NSSharingService?
    ) {
        Task { @MainActor in
            picker = nil
        }
    }
}
