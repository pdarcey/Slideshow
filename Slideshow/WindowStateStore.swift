//
//  WindowStateStore.swift
//  Slideshow
//
//  Created by Paul Darcey on 27/8/2026.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.xerodonia.Slideshow", category: "WindowStateStore")

/// Persists the list of currently-open windows' state (folder bookmark +
/// selected image) across launches, so the app can restore each window
/// independently on the next launch.
///
/// A plain `UserDefaults`-backed helper rather than `@AppStorage`, since
/// `@AppStorage` doesn't support arrays of `Codable` structs directly.
enum WindowStateStore {
    private static let key = "openWindows"

    static func load() -> [WindowState] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([WindowState].self, from: data)
        } catch {
            logger.error("Failed to decode persisted window state: \(error)")
            return []
        }
    }

    static func save(_ states: [WindowState]) {
        do {
            let data = try JSONEncoder().encode(states)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            logger.error("Failed to encode window state for persistence: \(error)")
        }
    }
}
