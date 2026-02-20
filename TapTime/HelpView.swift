//
//  HelpView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        helpStep(number: "1", text: "Tap on the map to add one or more locations that you want to include in the time zone calculations. Your location is automatically included, so you don't have to tap it on the map!")

                        helpStep(number: "2", text: "Tap the Choose Date and Time button.")

                        helpStep(number: "3", text: "The location marked in pink in the list is the anchor time zone against which other locations will be compared. By default, that's your current location, but you can change the anchor time zone by tapping one of the other locations in the list.")

                        helpStep(number: "4", text: "Tap the Calendar button to set the date, and use the slider to set the time for the anchor location. All the other locations will reflect their local times, compared to the anchor location.")

                        helpStep(number: "5", text: "You can export the list of times using the Share button.")
                    }
                }
                .padding()
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
