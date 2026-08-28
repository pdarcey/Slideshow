//
//  SlideTransition.swift
//  Slideshow
//
//  Created by Paul Darcey on 9/8/2025.
//

import Foundation

/// How consecutive slides transition when advancing.
enum SlideTransition: String, CaseIterable, Identifiable {
    case crossFade
    case cut

    var id: Self { self }

    var label: String {
        switch self {
        case .crossFade: "Cross-fade"
        case .cut: "None"
        }
    }
}
