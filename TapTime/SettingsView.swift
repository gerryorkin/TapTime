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

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Use Larger Pills", isOn: $useLargePills)
                } header: {
                    Text("Display Options")
                } footer: {
                    Text("Show location cards with larger text and increased padding")
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
