//
//  Settings.swift
//  Slideshow
//
//  Created by Paul Darcey on 9/8/2025.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("autoModeInterval") var interval: Double = 3.0
    @AppStorage("autoMode") var autoMode: Bool = true
    @AppStorage("showMetadata") var showMetadata = true

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Auto Mode", isOn: $autoMode)
            Slider(value: $interval, in: 0...5, step: 0.1) {
                Text("Advance slides every: \(interval.formatted(.number.precision(.fractionLength(1)))) seconds")
                    .monospacedDigit()
            }
            Toggle("Show Metadata", isOn: $showMetadata)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
