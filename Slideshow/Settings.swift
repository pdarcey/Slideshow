//
//  Settings.swift
//  Slideshow
//
//  Created by Paul Darcey on 9/8/2025.
//

import SwiftUI

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

struct SettingsView: View {
    @AppStorage("autoModeInterval") var interval: Double = 3.0
    @AppStorage("autoMode") var autoMode: Bool = true
    @AppStorage("showMetadata") var showMetadata = true
    @AppStorage("slideTransition") var slideTransition: SlideTransition = .crossFade
    @AppStorage("transitionDuration") var transitionDuration: Double = 0.35

    var body: some View {
        Form {
            Section("Slideshow") {
                Toggle("Auto Mode", isOn: $autoMode)
                Slider(value: $interval, in: 0...5, step: 0.1) {
                    Text("Advance slides every: \(interval.formatted(.number.precision(.fractionLength(1)))) seconds")
                        .monospacedDigit()
                }
                Toggle("Show Metadata", isOn: $showMetadata)
            }

            Section("Transitions") {
                Picker("Style", selection: $slideTransition) {
                    ForEach(SlideTransition.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                Slider(value: $transitionDuration, in: 0.1...2.0, step: 0.05) {
                    Text("Transition speed: \(transitionDuration.formatted(.number.precision(.fractionLength(2)))) seconds")
                        .monospacedDigit()
                }
                .disabled(slideTransition == .cut)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 380)
    }
}

#Preview {
    SettingsView()
}
