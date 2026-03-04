//
//  SettingsView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct SettingsView: View {
    @Binding var useLargePills: Bool
    @Environment(\.dismiss) private var dismiss

    // Pill appearance properties kept for future use
    @AppStorage("pillOpacity") private var pillOpacity: Double = 0.9
    @AppStorage("pillColorData") private var pillColorData: Data = defaultPillColorData
    @AppStorage("APP_backgroundStyle") private var backgroundStyle: String = "photos"
    @AppStorage("APP_fullToneBackground") private var fullToneBackground: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Use Larger Buttons", isOn: $useLargePills)
                } header: {
                    Text("Display Options")
                } footer: {
                    Text("Show location buttons with larger text and increased padding")
                }

                Section {
                    Picker("Row Background", selection: $backgroundStyle) {
                        Text("Photos").tag("photos")
                        Text("Map").tag("map")
                        Text("Flag").tag("flag")
                        Text("None").tag("none")
                    }

                    if backgroundStyle == "photos" {
                        Button(role: .destructive) {
                            LandmarkPhotoService.shared.clearCache()
                        } label: {
                            Label("Refresh Photos", systemImage: "arrow.clockwise")
                        }
                    }

                    if backgroundStyle == "map" {
                        Button(role: .destructive) {
                            MapSnapshotService.shared.clearCache()
                        } label: {
                            Label("Refresh Maps", systemImage: "arrow.clockwise")
                        }
                    }
                    if backgroundStyle != "none" && backgroundStyle != "photos" {
                        Toggle("Full Tone", isOn: $fullToneBackground)
                    }
                } header: {
                    Text("Row Background")
                } footer: {
                    Text(fullToneBackground && backgroundStyle != "none"
                         ? "Background images shown at full intensity"
                         : "Choose what to show behind each location row")
                }

                Section {
                    Text("Made by Gerry Orkin in beautiful Austinmer, New South Wales.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
