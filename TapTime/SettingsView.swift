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
