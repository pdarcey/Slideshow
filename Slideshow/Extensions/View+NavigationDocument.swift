//
//  View+NavigationDocument.swift
//  Slideshow
//
//  Created by Paul Darcey on 15/9/2026.
//

import SwiftUI

extension View {
    /// An optional-`URL` overload of `navigationDocument(_:)`, which only
    /// takes a non-optional `URL` — so a window with no folder loaded yet
    /// can still sit in the same modifier chain as one that has. No-op
    /// (and, on macOS, no proxy icon/title-bar path popup) when `url` is
    /// nil.
    @ViewBuilder
    func navigationDocument(_ url: URL?) -> some View {
        if let url {
            self.navigationDocument(url)
        } else {
            self
        }
    }
}
